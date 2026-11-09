import Foundation

/// Decision 0042, H: what checks and follow-ups really cost, from what the
/// proxy reports for each call. Shown in Settings → Developer (test builds).
public struct CostMeter: Codable, Equatable, Sendable {
    /// One call's tokens, as the API counted them.
    public struct Tokens: Codable, Equatable, Sendable {
        public var fresh: Int
        public var cacheRead: Int
        public var cacheWrite: Int
        public var output: Int

        public init(fresh: Int = 0, cacheRead: Int = 0, cacheWrite: Int = 0, output: Int = 0) {
            self.fresh = fresh
            self.cacheRead = cacheRead
            self.cacheWrite = cacheWrite
            self.output = output
        }

        public static func + (a: Tokens, b: Tokens) -> Tokens {
            Tokens(fresh: a.fresh + b.fresh, cacheRead: a.cacheRead + b.cacheRead, cacheWrite: a.cacheWrite + b.cacheWrite, output: a.output + b.output)
        }

        /// Share of the prompt read from cache.
        public var hitRate: Double {
            let prompt = fresh + cacheRead + cacheWrite
            return prompt == 0 ? 0 : Double(cacheRead) / Double(prompt)
        }
    }

    public struct Check: Codable, Equatable, Sendable {
        public var at: Date
        public var researchUSD: Double
        public var scoringUSD: Double
        public var briefUSD: Double
        public var tokens: Tokens

        public init(at: Date, researchUSD: Double, scoringUSD: Double, briefUSD: Double, tokens: Tokens) {
            self.at = at
            self.researchUSD = researchUSD
            self.scoringUSD = scoringUSD
            self.briefUSD = briefUSD
            self.tokens = tokens
        }

        public var totalUSD: Double { researchUSD + scoringUSD + briefUSD }
    }

    public struct FollowUpCost: Codable, Equatable, Sendable {
        public var at: Date
        public var kind: String
        public var usd: Double
        public var tokens: Tokens

        public init(at: Date, kind: String, usd: Double, tokens: Tokens) {
            self.at = at
            self.kind = kind
            self.usd = usd
            self.tokens = tokens
        }
    }

    public var checks: [Check]
    public var followUps: [FollowUpCost]
    public static let keep = 50

    public init(checks: [Check] = [], followUps: [FollowUpCost] = []) {
        self.checks = checks
        self.followUps = followUps
    }

    public mutating func record(_ c: Check) { checks = Array((checks + [c]).suffix(Self.keep)) }
    public mutating func record(_ f: FollowUpCost) { followUps = Array((followUps + [f]).suffix(Self.keep)) }

    private static func mean(_ xs: [Double]) -> Double? { xs.isEmpty ? nil : xs.reduce(0, +) / Double(xs.count) }

    public struct Summary: Equatable, Sendable {
        public var checks: Int
        public var perCheckUSD: Double
        public var researchUSD: Double
        public var scoringUSD: Double
        public var briefUSD: Double
        /// Share of all prompt tokens read from cache, checks and follow-ups.
        public var cacheHitRate: Double
        public var followUps: Int
        public var perFollowUpUSD: Double?
    }

    public var summary: Summary? {
        guard let total = Self.mean(checks.map(\.totalUSD)) else { return nil }
        let tokens = (checks.map(\.tokens) + followUps.map(\.tokens)).reduce(Tokens(), +)
        return Summary(checks: checks.count, perCheckUSD: total,
                       researchUSD: Self.mean(checks.map(\.researchUSD)) ?? 0,
                       scoringUSD: Self.mean(checks.map(\.scoringUSD)) ?? 0,
                       briefUSD: Self.mean(checks.map(\.briefUSD)) ?? 0,
                       cacheHitRate: tokens.hitRate,
                       followUps: followUps.count,
                       perFollowUpUSD: Self.mean(followUps.map(\.usd)))
    }
}
