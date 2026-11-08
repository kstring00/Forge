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
        /// The user tapped Stop. What the proxy had already charged is in `spentUSD`.
        case stopped(String)
        case overCeiling(estimate: Double, remaining: Double)
    }

    private(set) var phase: Phase = .idle
    private(set) var litSpheres: Set<Sphere> = []
    private(set) var spentUSD: Double = 0
    private(set) var estimate: ClosedRange<Double> = 0.10...0.25

    private let proxy: ProxyAIClient?
    private var lightingTask: Task<Void, Never>?
    /// The task running `run`, so Stop can cancel the remaining proxy calls.
    private var runTask: Task<Void, Never>?
    /// Library sources this run saved; removed again if the run is stopped.
    private var savedThisRun: [Source] = []

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

    /// Runs as a cancellable task. Stop cancels it between or during proxy calls.
    func start(on idea: Idea, in context: ModelContext, advantages: [String] = [], constraints: [String] = []) async {
        guard !isRunning else { return }
        let task = Task { @MainActor [weak self] in
            await self?.run(on: idea, in: context, advantages: advantages, constraints: constraints)
        }
        runTask = task
        await task.value
        runTask = nil
    }

    /// Stops the run. Remaining proxy calls are cancelled; nothing half-finished is kept.
    func stop() {
        guard isRunning else { return }
        runTask?.cancel()
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
        savedThisRun = []
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
                try Task.checkCancellation()
                gathered.append(contentsOf: r.sources)
                if !r.notes.isEmpty { notes = r.notes }
                phase = .researching(turn: turn, sources: gathered.filter { $0.kind == "fetched" }.count)
                if r.status == "done" { break }
                messages = r.messages
            }
            savedThisRun = PrefillApplier.saveResearch(gathered, notes: notes, to: idea)
            pagesSaved = savedThisRun.count
            try? context.save()

            // 2. The Spheres pre-fill the Lab.
            step = .prefill
            phase = .prefilling
            startLighting()
            let envelope = try await proxy.perform(.prefill, context: AIContext.make(for: idea), expecting: PrefillResult.self)
            stopLighting()
            spendRecord(envelope.costUSD ?? 0)
            try Task.checkCancellation()

            // 3. Records.
            phase = .applying
            let applied = PrefillApplier.apply(envelope.payload, rationale: envelope.rationale, costUSD: spentUSD, to: idea, in: context)
            litSpheres = Set(Sphere.phase3Panel)
            AISpend.lastRealityCheckUSD = spentUSD
            applied.realityCheck.actualCostUSD = spentUSD
            try? context.save()
            phase = .done
        } catch is CancellationError {
            stopLighting()
            litSpheres = []
            discardSaved(in: context, from: idea)
            phase = .stopped(Self.stoppedLine(step: step, spentUSD: spentUSD))
        } catch {
            stopLighting()
            litSpheres = []
            if (error as? URLError)?.code == .cancelled {
                discardSaved(in: context, from: idea)
                phase = .stopped(Self.stoppedLine(step: step, spentUSD: spentUSD))
                return
            }
            phase = Self.failurePhase(error, step: step, pagesSaved: pagesSaved, spentUSD: spentUSD)
        }
    }

    /// Stop keeps nothing: the pages this run saved go back out of the Library.
    private func discardSaved(in context: ModelContext, from idea: Idea) {
        for s in savedThisRun {
            idea.sources.removeAll { $0.id == s.id }
            context.delete(s)
        }
        savedThisRun = []
        try? context.save()
    }

    /// What Stop leaves behind: the step it stopped in, and that the spend is in Settings.
    static func stoppedLine(step: Step, spentUSD: Double) -> String {
        let at = step == .research ? "during the desk research" : "before the Brief was written"
        let spent = spentUSD > 0 ? " What the proxy had already done is counted in Settings → Spend." : " Nothing was charged."
        return "Stopped \(at). Nothing was saved.\(spent)"
    }

    enum Step { case research, prefill }

    /// Every failure says what broke and what was kept, so the card can show
    /// it rather than quietly going back to idle. No prices: Settings → Spend
    /// has those.
    static func failurePhase(_ error: Error, step: Step, pagesSaved: Int, spentUSD: Double) -> Phase {
        let what = step == .research ? "The desk research stopped" : "The panel stopped before the Brief"
        let kept = pagesSaved > 0
            ? " \(pagesSaved) \(pagesSaved == 1 ? "source it found is" : "sources it found are") saved in the Library."
            : " Nothing was saved."
        let spent = spentUSD > 0 ? " What was already done is counted in Settings → Spend." : ""
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
