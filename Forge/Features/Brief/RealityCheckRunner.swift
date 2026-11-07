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
    private(set) var estimate: ClosedRange<Double> = 0.15...0.60

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
            _ = PrefillApplier.saveResearch(gathered, notes: notes, to: idea)
            try? context.save()

            // 2. The Spheres pre-fill the Lab.
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
        } catch let error as AIError {
            stopLighting()
            switch error {
            case .offline, .notConfigured: phase = .offline("AI isn't reachable right now. Nothing was changed.")
            case .rateLimited: phase = .failed("The proxy is rate limiting. Try again in a minute.")
            case .invalidResponse(let d): phase = .failed("The AI step failed. \(d)")
            case .server(let s): phase = .failed("The proxy answered with status \(s).")
            }
        } catch {
            stopLighting()
            phase = .failed(error.localizedDescription)
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
