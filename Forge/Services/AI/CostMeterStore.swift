import Foundation
import ForgeCore

/// Decision 0042, H: the cost meter on this phone. Every check and included
/// follow-up records what the proxy said each call cost; Settings → Developer
/// (test builds) shows the averages and the cache hit rate.
enum CostMeterStore {
    static let key = "costMeter"
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static var meter: CostMeter {
        defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(CostMeter.self, from: $0) } ?? CostMeter()
    }

    private static func save(_ m: CostMeter) {
        if let d = try? JSONEncoder().encode(m) { defaults.set(d, forKey: key) }
    }

    static func tokens<P: Codable & Sendable>(_ u: AIEnvelope<P>.Usage?) -> CostMeter.Tokens {
        guard let u else { return .init() }
        return .init(fresh: u.inputTokens, cacheRead: u.cacheReadTokens, cacheWrite: u.cacheWriteTokens, output: u.outputTokens)
    }

    /// A finished check: research turns, then the prefill's stages.
    static func recordCheck<P: Codable & Sendable>(researchUSD: Double, researchTokens: CostMeter.Tokens, prefill: AIEnvelope<P>) {
        let stages = prefill.stages ?? []
        let scoring = stages.filter { $0.stage == "scoring" }.reduce(0) { $0 + $1.costUSD }
        // An older proxy sends no stages: the whole prefill counts as the Brief.
        let brief = stages.isEmpty ? (prefill.costUSD ?? 0) : stages.filter { $0.stage == "brief" }.reduce(0) { $0 + $1.costUSD }
        var m = meter
        m.record(CostMeter.Check(at: .now, researchUSD: researchUSD, scoringUSD: scoring, briefUSD: brief,
                                 tokens: researchTokens + tokens(prefill.usage)))
        save(m)
    }

    static func recordFollowUp<P: Codable & Sendable>(_ kind: FollowUp, _ envelope: AIEnvelope<P>) {
        var m = meter
        m.record(CostMeter.FollowUpCost(at: .now, kind: kind.rawValue, usd: envelope.costUSD ?? 0, tokens: tokens(envelope.usage)))
        save(m)
    }
}
