import Foundation
import Observation
import SwiftData
import ForgeCore

/// Decision 0041: makes and refreshes launch plans. Held by AppEnvironment so
/// a plan keeps writing while the person moves around the app. Checks are
/// spent only when a plan arrives; a failed one costs nothing.
@Observable
@MainActor
final class PlanBuilder {
    private(set) var running: Set<UUID> = []
    private(set) var failures: [UUID: String] = [:]

    let proxy: ProxyAIClient?
    weak var entitlements: (any EntitlementService)?
    /// Panel takes running now hold their checks against a plan's cost.
    weak var checks: RealityCheckCenter?

    init(proxy: ProxyAIClient?) {
        self.proxy = proxy
    }

    var isConfigured: Bool { proxy != nil }

    func isRunning(_ ideaID: UUID) -> Bool { running.contains(ideaID) }
    func failure(for ideaID: UUID) -> String? { failures[ideaID] }
    func dismissFailure(_ ideaID: UUID) { failures[ideaID] = nil }

    /// A plan needs something to stand on: the panel has looked at the idea.
    static func isEligible(_ idea: Idea) -> Bool {
        !idea.isArchived && (idea.latestRealityCheck != nil || idea.latestEvaluation != nil)
    }

    private var membershipPlan: Plan { entitlements?.state.plan ?? .free }

    /// Checks this idea's plan costs now: a new plan or bringing one up to date.
    func cost(for idea: Idea) -> Int { PlanCost.checks(on: membershipPlan, refreshing: idea.launchPlanData != nil) }
    /// "Included" (decision 0042), or a number of checks if the rules charge.
    func costLabel(for idea: Idea) -> String { PlanCost.label(on: membershipPlan, refreshing: idea.launchPlanData != nil) }

    func canAfford(_ idea: Idea) -> Bool {
        entitlements?.canSpend(cost(for: idea), inFlight: checks?.runningCount ?? 0) ?? true
    }

    func build(_ idea: Idea, in context: ModelContext) {
        let id = idea.id
        guard !running.contains(id) else { return }
        guard let proxy else {
            failures[id] = "Plans need the panel, and Hunch can't reach it in this build."
            return
        }
        let checksToSpend = cost(for: idea)
        // Decision 0042: included, under a quiet daily limit per idea.
        let kind: FollowUp = idea.launchPlanData != nil ? .launchPlanUpdate : .launchPlan
        if let e = entitlements, !e.canUse(kind, ideaID: id) {
            failures[id] = kind.limitMessage
            return
        }
        guard canAfford(idea) else {
            failures[id] = "This plan needs \(checksToSpend) \(checksToSpend == 1 ? "check" : "checks"), and there aren't enough left."
            return
        }
        failures[id] = nil
        running.insert(id)

        var ctx = AIContext.make(for: idea)
        let charter = (try? context.fetch(FetchDescriptor<StewardCharter>()))?.first
        if let charter, !charter.isPlaceholder { ctx.stewardCharter = charter.text }
        ctx.advantages = ((try? context.fetch(FetchDescriptor<Advantage>())) ?? []).map(\.text).filter { !$0.isEmpty }
        ctx.constraints = ((try? context.fetch(FetchDescriptor<Constraint>())) ?? []).map(\.text).filter { !$0.isEmpty }
        let options = Self.options(for: idea)
        let basis = Self.basis(for: idea)

        Task { @MainActor [weak self] in
            do {
                let envelope = try await proxy.perform(.launchPlan, context: ctx, options: options, expecting: LaunchPlanResult.self)
                AISpend.record(envelope.costUSD ?? 0)
                idea.launchPlan = Self.plan(from: envelope.payload, rationale: envelope.rationale, basis: basis)
                idea.touch()
                try? context.save()
                self?.entitlements?.spend(checksToSpend)
                self?.entitlements?.recordUse(kind, ideaID: id)
                self?.running.remove(id)
            } catch {
                self?.running.remove(id)
                if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
                self?.failures[id] = Self.message(error)
            }
        }
    }

    // MARK: What the plan is built from

    /// What the panel can't read from the Library: where proof is, the
    /// verdict, the estimate, the riskiest belief, the step in progress.
    static func options(for idea: Idea) -> [String: String] {
        var o: [String: String] = [:]
        let stage = ProofStage.of(idea)
        o["proofStage"] = "\(stage.cardWord), \(stage.stepOfFour) (looked up online, gave time, paid, came back)"
        switch stage {
        case .paid, .cameBack: o["paid"] = "Someone has paid."
        default: o["paid"] = "No one has paid yet."
        }
        o["conversationsLogged"] = String(conversations(idea))
        if let check = idea.latestRealityCheck { o["verdict"] = check.verdict.displayName }
        if let e = idea.latestEvaluation {
            if !e.criteria.isEmpty { o["potential"] = PotentialWord.word(e.potential) }
            let risk = e.riskiestAssumption.trimmingCharacters(in: .whitespacesAndNewlines)
            if !risk.isEmpty { o["riskiestAssumption"] = risk }
            if let inputs = e.estimateInputs, let m = PlanMoney(inputs) {
                o["estimate"] = "about \(LaunchPlanDocument.dollars(m.price)) a month per customer, about \(m.customers) reachable in year one, \(m.sharePercent) who pay"
            } else {
                o["estimate"] = "Too early to estimate: no sourced price."
            }
        }
        if let step = idea.project?.nextStep, !step.isEmpty { o["currentStep"] = step }
        return o
    }

    static func conversations(_ idea: Idea) -> Int {
        idea.sources.filter { $0.sourceClass == .userVerified && $0.title.hasPrefix(FieldEvidence.conversationKind) }.count
    }

    static func basis(for idea: Idea) -> LaunchPlan.Basis {
        .init(conversations: conversations(idea), proofStep: ProofStage.of(idea).ladderIndex, checkedAt: idea.latestRealityCheck?.createdAt)
    }

    /// What moved since the plan was made, in words. Empty when nothing did.
    static func changes(since plan: LaunchPlan, for idea: Idea) -> [String] {
        LaunchPlan.changes(from: plan.basis, to: basis(for: idea))
    }

    static func plan(from r: LaunchPlanResult, rationale: String, basis: LaunchPlan.Basis, now: Date = .now) -> LaunchPlan {
        let blocks = [r.days1to30, r.days31to60, r.days61to90]
        return LaunchPlan(
            oneLine: r.oneLine, forWho: r.forWho,
            proven: r.proven.map { .init(text: $0.text, sourceID: $0.sourceID) },
            unproven: r.unproven, riskiest: r.riskiest,
            phases: zip(LaunchPlan.dayLabels, blocks).map { .init(days: $0.0, title: $0.1.title, detail: $0.1.detail, decide: $0.1.decide) },
            customerNoun: r.customerNoun, stopRule: r.stopRule,
            stewardNote: r.stewardNote.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 },
            rationale: rationale, createdAt: now, basis: basis)
    }

    /// Plain words; nothing was charged.
    static func message(_ error: Error) -> String {
        switch error as? AIError {
        case .offline?: "The plan didn't finish: the connection dropped. Try again when you're online. No checks were used."
        case .rateLimited?: "The panel is busy. Try again in a minute. No checks were used."
        default: "The plan didn't finish. No checks were used. Try again in a little while."
        }
    }
}
