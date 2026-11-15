import Foundation

/// The plan the app tells the proxy it is on, with each request (decision
/// 0046). The proxy holds free-tier checks back once the day's spend passes
/// 70% of its ceiling and serves paid plans to 100%, so it has to know which
/// this is. Read straight from the saved membership state, so the network
/// client needs nothing from the main actor.
public enum PlanSignal {
    /// Where `LocalEntitlements` saves the membership state.
    public static let stateKey = "membership.state"

    /// "free", "plus" or "pro". Free when nothing is saved or it can't be read.
    public static func current(defaults: UserDefaults = .standard) -> String {
        guard let data = defaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(MembershipState.self, from: data) else { return Plan.free.rawValue }
        return state.plan.rawValue
    }
}

/// What the owner's Spend screen shows, as the proxy's `/api/spend` sends it.
public struct OwnerSpend: Codable, Equatable, Sendable {
    public struct Period: Codable, Equatable, Sendable {
        public var from: String
        public var to: String
        public var days: Int
        public var usd: Double
        public var checks: Int
        public var checkUSD: Double
        public var averagePerCheckUSD: Double?
    }

    public var day: String
    public var timeZone: String
    public var ceilingUSD: Double
    public var freeTierStopsAtUSD: Double
    /// "open", "paidOnly" or "resting".
    public var state: String
    public var today: Period
    public var week: Period
    public var month: Period

    /// "$1.42 of $3.00 today".
    public var todayLine: String { "\(Self.money(today.usd)) of \(Self.money(ceilingUSD)) today" }

    /// Where today stands, in a plain sentence.
    public var stateLine: String {
        switch state {
        case "resting": "The ceiling is reached. Every check rests until midnight (\(timeZone))."
        case "paidOnly": "Past \(Self.money(freeTierStopsAtUSD)): free users can't start a check today. Paid plans carry on to \(Self.money(ceilingUSD))."
        default: "Everyone is being served. Free checks stop at \(Self.money(freeTierStopsAtUSD)); everything stops at \(Self.money(ceilingUSD))."
        }
    }

    /// How far through the day's ceiling, from 0 to 1.
    public var share: Double { ceilingUSD > 0 ? min(1, max(0, today.usd / ceilingUSD)) : 0 }

    /// "12 checks · 17¢ each", or "No checks yet".
    public static func checksLine(_ p: Period) -> String {
        guard p.checks > 0 else { return "No checks yet" }
        let count = "\(p.checks) \(p.checks == 1 ? "check" : "checks")"
        guard let each = p.averagePerCheckUSD else { return count }
        return "\(count) · \(Int((each * 100).rounded()))¢ each"
    }

    public static func money(_ usd: Double) -> String {
        usd > 0 && usd < 0.01 ? "<$0.01" : String(format: "$%.2f", usd)
    }
}
