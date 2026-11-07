import Foundation
import Observation
import SwiftData
import ForgeCore

/// Drives one Reality Check: research turns until done, pages saved as
/// ai-found Sources, then the Spheres' prefill, then the records. The orbs
/// read `workingSpheres` and `litSpheres` to light up in sequence.
@Observable
@MainActor
final class RealityCheckRunner {
    enum Phase: Equatable {
        case idle
        case researching(turn: Int, sources: Int)
        case prefilling
        case applying
        case done
        case offline(String)
        case failed(String)
        case overCeiling(estimate: Double, remaining: Double)
    }

    private(set) var phase: Phase = .idle
    private(set) var litSpheres: Set<Sphere> = []
    private(set) var spentUSD: Double = 0
    private(set) var estimate: ClosedRange<Double> = 0.10...0.25

    private let proxy: ProxyAIClient?
    private var lightingTask: Task<Void, Never>?

    static let maxResearchTurns = 4

    init(proxy: ProxyAIClient?) {
        self.proxy = proxy
    }

    var isRunning: Bool {
        switch phase {
        case .researching, .prefilling, .applying: true
        default: false
        }
    }

    func loadEstimate() async {
        guard let proxy else { return }
        if let h = try? await proxy.health() {
            estimate = h.estimate.realityCheckUSD.low...h.estimate.realityCheckUSD.high
        }
    }

    func run(on idea: Idea, in context: ModelContext, advantages: [String] = [], constraints: [String] = []) async {
        guard !isRunning else { return }
        guard let proxy else {
            phase = .offline("The Reality Check needs the AI proxy, which isn't configured yet.")
            return
        }
        if AISpend.wouldExceed(estimate: estimate.upperBound) {
            phase = .overCeiling(estimate: estimate.upperBound, remaining: AISpend.remainingUSD())
            return
        }
        litSpheres = []
        spentUSD = 0
        var step = Step.research
        var pagesSaved = 0
        do {
            // 1. Research, one turn per call.
            var messages: [JSONValue]? = nil
            var gathered: [ResearchResponse.Source] = []
            var notes = ""
            for turn in 1...Self.maxResearchTurns {
                phase = .researching(turn: turn, sources: gathered.count)
                let r = try await proxy.research(ideaID: idea.id, title: idea.title, originalText: idea.originalText,
                                                 advantages: advantages, constraints: constraints, messages: messages)
                spendRecord(r.costUSD)
                gathered.append(contentsOf: r.sources)
                if !r.notes.isEmpty { notes = r.notes }
                phase = .researching(turn: turn, sources: gathered.filter { $0.kind == "fetched" }.count)
                if r.status == "done" { break }
                messages = r.messages
            }
            pagesSaved = PrefillApplier.saveResearch(gathered, notes: notes, to: idea).count
            try? context.save()

            // 2. The Spheres pre-fill the Lab.
            step = .prefill
            phase = .prefilling
            startLighting()
            let envelope = try await proxy.perform(.prefill, context: AIContext.make(for: idea), expecting: PrefillResult.self)
            stopLighting()
            spendRecord(envelope.costUSD ?? 0)

            // 3. Records.
            phase = .applying
            let applied = PrefillApplier.apply(envelope.payload, rationale: envelope.rationale, costUSD: spentUSD, to: idea, in: context)
            litSpheres = Set(Sphere.phase3Panel)
            AISpend.lastRealityCheckUSD = spentUSD
            applied.realityCheck.actualCostUSD = spentUSD
            try? context.save()
            phase = .done
        } catch {
            stopLighting()
            litSpheres = []
            phase = Self.failurePhase(error, step: step, pagesSaved: pagesSaved, spentUSD: spentUSD)
        }
    }

    enum Step { case research, prefill }

    /// Every failure says what broke, what was kept and what it cost, so the
    /// card can show it rather than quietly going back to idle.
    static func failurePhase(_ error: Error, step: Step, pagesSaved: Int, spentUSD: Double) -> Phase {
        let what = step == .research ? "The desk research stopped" : "The panel stopped before the Brief"
        let kept = pagesSaved > 0
            ? " \(pagesSaved) \(pagesSaved == 1 ? "source it found is" : "sources it found are") saved in the Library."
            : " Nothing was saved."
        let spent = spentUSD > 0 ? " This attempt cost \(AISpend.format(spentUSD))." : ""
        guard let ai = error as? AIError else {
            let d = error.localizedDescription
            return .failed("\(what): \(d.hasSuffix(".") ? d : d + ".")\(kept)\(spent)")
        }
        switch ai {
        case .offline:
            return .offline("\(what): the connection to the proxy dropped or timed out.\(kept)\(spent) Try again when you're online.")
        case .notConfigured:
            return .failed("\(what): the proxy refused the request. Check PROXY_TOKEN in Local.xcconfig against FORGE_PROXY_TOKEN on Vercel, and that ANTHROPIC_API_KEY is set.\(kept)")
        case .rateLimited:
            return .failed("\(what): the proxy is rate limiting. Try again in a minute.\(kept)\(spent)")
        case .invalidResponse(let d):
            let detail = d.hasSuffix(".") ? d : d + "."
            return .failed("\(what): \(detail)\(kept)\(spent)")
        case .server(let s):
            return .failed("\(what): the proxy answered with status \(s).\(kept)\(spent) Vercel → Logs has the detail.")
        }
    }

    func reset() {
        stopLighting()
        phase = .idle
        litSpheres = []
    }

    private func spendRecord(_ usd: Double) {
        spentUSD += usd
        AISpend.record(usd)
    }

    /// While the prefill runs, light one Sphere every few seconds so the wait reads as work.
    private func startLighting() {
        lightingTask?.cancel()
        lightingTask = Task { @MainActor [weak self] in
            for sphere in Sphere.phase3Panel {
                try? await Task.sleep(for: .seconds(6))
                if Task.isCancelled { return }
                self?.litSpheres.insert(sphere)
            }
        }
    }

    private func stopLighting() {
        lightingTask?.cancel()
        lightingTask = nil
    }
}
