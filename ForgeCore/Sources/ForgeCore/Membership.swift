import Foundation

/// Decision 0032 (from docs/PRICING.md, decision 0031): Free / Plus / Pro, and a
/// check as the only unit. Pure: no StoreKit, no storage. The app feeds it what
/// the App Store says; the ledger answers whether a check may start.
public enum Plan: String, Codable, CaseIterable, Sendable, Comparable {
    case free, plus, pro

    public var displayName: String {
        switch self {
        case .free: "Free"
        case .plus: "Plus"
        case .pro: "Pro"
        }
    }

    /// Checks a month on this plan, from the rules in force (decision 0042).
    public var monthlyChecks: Int { PlanRules.current.monthlyChecks(for: self) }

    public func includes(_ feature: PlanFeature) -> Bool {
        switch feature {
        // Decision 0040: What-ifs (Sparks) are free on every plan.
        // Decision 0042: the Library is your own work, on every plan.
        case .whatIf, .library: true
        case .priority, .deepResearch, .reports: self == .pro
        }
    }

    private var rank: Int { switch self { case .free: 0; case .plus: 1; case .pro: 2 } }
    public static func < (a: Plan, b: Plan) -> Bool { a.rank < b.rank }
}

/// What a plan unlocks beyond checks. Your own work (capture, the Vault, steps,
/// logging, rulings, the Journal, the Library, Your patterns' data) is never
/// locked. Decision 0042: "Argue it out" is gone; arguing with the panel is the
/// Tank, included on every plan.
public enum PlanFeature: String, Sendable {
    case whatIf, library, priority, deepResearch, reports
}

/// App Store product ids, as in docs/PRICING.md and Hunch.storekit.
public enum MembershipProduct {
    public static let groupName = "Hunch Membership"
    public static let plusMonthly = "hunch.plus.monthly"
    public static let plusYearly = "hunch.plus.yearly"
    public static let plusFoundingYearly = "hunch.plus.founding.yearly"
    public static let proMonthly = "hunch.pro.monthly"
    public static let proYearly = "hunch.pro.yearly"
    public static let topUp5 = "hunch.topup.5"
    /// Checks in one top-up, from the rules in force (decision 0042).
    public static var topUpChecks: Int { PlanRules.current.topUpChecks }

    public static let subscriptions = [plusMonthly, plusYearly, plusFoundingYearly, proMonthly, proYearly]
    public static let all = subscriptions + [topUp5]

    public static func plan(for productID: String) -> Plan? {
        switch productID {
        case plusMonthly, plusYearly, plusFoundingYearly: .plus
        case proMonthly, proYearly: .pro
        default: nil
        }
    }

    /// Shown before the App Store answers, and in tests. The App Store's own
    /// localized price replaces these on screen.
    public static func fallbackPrice(_ id: String) -> Decimal {
        switch id {
        case plusMonthly: 9.99
        case plusYearly: 59.99
        case plusFoundingYearly: 39.99
        case proMonthly: 24.99
        case proYearly: 179.99
        case topUp5: 2.99
        default: 0
        }
    }

    /// "save 50%": a year against twelve months.
    public static func yearlySaving(monthly: Decimal, yearly: Decimal) -> Int {
        guard monthly > 0 else { return 0 }
        let twelve = monthly * 12
        let pct = (twelve - yearly) / twelve * 100
        return Int(NSDecimalNumber(decimal: pct).doubleValue.rounded())
    }
}

/// What the App Store says about this person right now.
public struct MembershipState: Codable, Equatable, Sendable {
    public var plan: Plan
    /// In Plus's 7-day free trial: checks are capped at `trialChecks`.
    public var isTrial: Bool
    /// The subscription's original purchase: monthly checks reset on its day
    /// of the month. Nil on Free, which resets on the 1st.
    public var anchor: Date?
    public var productID: String?
    public var renewsAt: Date?
    public var founding: Bool

    /// Plus's trial cap, from the rules in force (decision 0042).
    public static var trialChecks: Int { PlanRules.current.trialChecks }
    public static let free = MembershipState(plan: .free, isTrial: false, anchor: nil, productID: nil, renewsAt: nil, founding: false)

    public init(plan: Plan, isTrial: Bool, anchor: Date?, productID: String?, renewsAt: Date?, founding: Bool) {
        self.plan = plan
        self.isTrial = isTrial
        self.anchor = anchor
        self.productID = productID
        self.renewsAt = renewsAt
        self.founding = founding
    }

    public var monthlyAllowance: Int { isTrial ? min(Self.trialChecks, plan.monthlyChecks) : plan.monthlyChecks }
}

/// When monthly checks reset.
public enum CheckPeriod {
    /// The start of the period containing `now`. Free: the 1st of the month.
    /// Paid: the latest monthly anniversary of the anchor (Jan 31 → Feb 28 → Mar 31).
    public static func start(containing now: Date, anchor: Date?, calendar: Calendar = .current) -> Date {
        guard let anchor else {
            return calendar.date(from: calendar.dateComponents([.year, .month], from: now)) ?? now
        }
        guard now > anchor else { return anchor }
        var k = calendar.dateComponents([.month], from: anchor, to: now).month ?? 0
        func at(_ k: Int) -> Date { calendar.date(byAdding: .month, value: k, to: anchor) ?? anchor }
        while k > 0 && at(k) > now { k -= 1 }
        while at(k + 1) <= now { k += 1 }
        return at(k)
    }

    /// When the period containing `now` ends.
    public static func nextReset(after now: Date, anchor: Date?, calendar: Calendar = .current) -> Date {
        let s = start(containing: now, anchor: anchor, calendar: calendar)
        guard let anchor else { return calendar.date(byAdding: .month, value: 1, to: s) ?? s }
        let k = calendar.dateComponents([.month], from: anchor, to: s).month ?? 0
        var next = calendar.date(byAdding: .month, value: k + 1, to: anchor) ?? s
        if next <= s { next = calendar.date(byAdding: .month, value: k + 2, to: anchor) ?? s }
        return next
    }
}

/// What can be spent right now.
public struct CheckBalance: Equatable, Sendable {
    public var monthlyLeft: Int
    public var monthlyAllowance: Int
    /// Decision 0042: last cycle's unused checks, spent first. They expire at
    /// `resetsAt`, the end of this cycle.
    public var rolledOverLeft: Int = 0
    /// Bought checks: used only after the monthly ones, never reset.
    public var topUps: Int
    public var resetsAt: Date
    /// This device's free first check (decision 0027) has not been used.
    public var firstFreeAvailable: Bool
    public var plan: Plan
    public var isTrial: Bool

    public var total: Int { rolledOverLeft + monthlyLeft + topUps }

    /// "3 of 15 checks left · resets Dec 1", with "+5 extra" when there are
    /// top-ups. The app passes the date already formatted.
    public func line(resets: String) -> String {
        if firstFreeAvailable { return "Your first check is free" }
        var s = "\(monthlyLeft) of \(monthlyAllowance) \(monthlyAllowance == 1 ? "check" : "checks") left"
        if rolledOverLeft > 0 { s += " · +\(rolledOverLeft) carried over" }
        if topUps > 0 { s += " · +\(topUps) extra" }
        return s + " · resets \(resets)"
    }

    /// The checks pill: everything that can be spent, and what expires soonest.
    /// "19 checks left · 4 expire Dec 3", or the plain line when nothing carried.
    public func pillLine(resets: String) -> String {
        if firstFreeAvailable || rolledOverLeft == 0 { return line(resets: resets) }
        return "\(total) \(total == 1 ? "check" : "checks") left · \(rolledOverLeft) carried over expire \(resets)"
    }
}

/// Decision 0032: how checks are counted, the same rules the proxy ledger will
/// keep. A check is counted only when its Brief arrives; a failed or stopped
/// one never counts.
///
/// Decision 0042, rollover: when a cycle ends, its unused monthly checks carry
/// into the next one, capped at one month's allowance (the smaller of the old
/// and the new plan's, so a downgrade or a cancel carries less). Carried checks
/// expire when that next cycle ends; they never carry twice. Trial checks
/// never carry. Spending order: the free first check, then carried-over (they
/// expire soonest), then this month's, then bought (they never expire).
public struct CheckLedger: Codable, Equatable, Sendable {
    public var periodStart: Date
    public var usedThisPeriod: Int
    public var topUps: Int
    public var firstFreeUsed: Bool
    /// Transaction ids already credited, so a top-up is never counted twice.
    public var creditedTransactions: [String]
    /// Checks carried into this cycle, and how many of them are spent.
    public var rolledOver: Int
    public var rolledOverUsed: Int
    /// This cycle's monthly allowance, kept for working out the carry when it ends.
    public var allowanceThisPeriod: Int?
    public var periodWasTrial: Bool
    /// When this cycle ends, as computed when it began.
    public var periodEnd: Date?

    public enum Spent: Equatable, Sendable { case firstFree, rolledOver, monthly, topUp, over }

    public init(periodStart: Date = .distantPast, usedThisPeriod: Int = 0, topUps: Int = 0, firstFreeUsed: Bool = false, creditedTransactions: [String] = [],
                rolledOver: Int = 0, rolledOverUsed: Int = 0, allowanceThisPeriod: Int? = nil, periodWasTrial: Bool = false, periodEnd: Date? = nil) {
        self.periodStart = periodStart
        self.usedThisPeriod = usedThisPeriod
        self.topUps = topUps
        self.firstFreeUsed = firstFreeUsed
        self.creditedTransactions = creditedTransactions
        self.rolledOver = rolledOver
        self.rolledOverUsed = rolledOverUsed
        self.allowanceThisPeriod = allowanceThisPeriod
        self.periodWasTrial = periodWasTrial
        self.periodEnd = periodEnd
    }

    /// Ledgers saved before rollover have none of its fields.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        periodStart = try c.decodeIfPresent(Date.self, forKey: .periodStart) ?? .distantPast
        usedThisPeriod = try c.decodeIfPresent(Int.self, forKey: .usedThisPeriod) ?? 0
        topUps = try c.decodeIfPresent(Int.self, forKey: .topUps) ?? 0
        firstFreeUsed = try c.decodeIfPresent(Bool.self, forKey: .firstFreeUsed) ?? false
        creditedTransactions = try c.decodeIfPresent([String].self, forKey: .creditedTransactions) ?? []
        rolledOver = try c.decodeIfPresent(Int.self, forKey: .rolledOver) ?? 0
        rolledOverUsed = try c.decodeIfPresent(Int.self, forKey: .rolledOverUsed) ?? 0
        allowanceThisPeriod = try c.decodeIfPresent(Int.self, forKey: .allowanceThisPeriod)
        periodWasTrial = try c.decodeIfPresent(Bool.self, forKey: .periodWasTrial) ?? false
        periodEnd = try c.decodeIfPresent(Date.self, forKey: .periodEnd)
    }

    /// What carries from the cycle that just ended into one that starts at
    /// `newStart` on `state`. A whole cycle passing unseen in between means
    /// that cycle's allowance went unused.
    func carry(into state: MembershipState, newStart: Date, rules: PlanRules) -> Int {
        guard rules.rollover.enabled, periodStart != .distantPast, !periodWasTrial, !state.isTrial else { return 0 }
        let oldAllowance = allowanceThisPeriod ?? state.monthlyAllowance
        let skippedACycle = periodEnd.map { newStart >= $0.addingTimeInterval(25 * 86_400) } ?? false
        let unused = skippedACycle ? oldAllowance : max(0, oldAllowance - usedThisPeriod)
        let cap = min(oldAllowance, state.monthlyAllowance) * max(0, rules.rollover.capMonths)
        return min(unused, cap)
    }

    /// A new cycle starts with no monthly checks used and last cycle's unused
    /// ones carried over. Bought checks stay.
    public mutating func roll(_ state: MembershipState, now: Date, rules: PlanRules = .current, calendar: Calendar = .current) {
        let s = CheckPeriod.start(containing: now, anchor: state.anchor, calendar: calendar)
        if s != periodStart {
            rolledOver = carry(into: state, newStart: s, rules: rules)
            rolledOverUsed = 0
            periodStart = s
            usedThisPeriod = 0
            periodEnd = CheckPeriod.nextReset(after: now, anchor: state.anchor, calendar: calendar)
        }
        // Within a cycle the plan can change (a trial ends): the latest one counts.
        allowanceThisPeriod = state.monthlyAllowance
        periodWasTrial = state.isTrial
    }

    public func balance(_ state: MembershipState, now: Date, rules: PlanRules = .current, calendar: Calendar = .current) -> CheckBalance {
        var l = self
        l.roll(state, now: now, rules: rules, calendar: calendar)
        let allowance = state.monthlyAllowance
        return CheckBalance(monthlyLeft: max(0, allowance - l.usedThisPeriod), monthlyAllowance: allowance,
                            rolledOverLeft: max(0, l.rolledOver - l.rolledOverUsed), topUps: l.topUps,
                            resetsAt: CheckPeriod.nextReset(after: now, anchor: state.anchor, calendar: calendar),
                            firstFreeAvailable: !l.firstFreeUsed, plan: state.plan, isTrial: state.isTrial)
    }

    /// Whether one more check may start while `inFlight` are already running.
    public func canStart(_ state: MembershipState, now: Date, inFlight: Int = 0, rules: PlanRules = .current, calendar: Calendar = .current) -> Bool {
        let b = balance(state, now: now, rules: rules, calendar: calendar)
        let available = b.total + (b.firstFreeAvailable ? 1 : 0)
        return available - inFlight > 0
    }

    /// Spends one check in order: carried-over, this month's, bought.
    mutating func spendOne(_ state: MembershipState) -> Spent {
        if rolledOverUsed < rolledOver {
            rolledOverUsed += 1
            return .rolledOver
        }
        if usedThisPeriod < state.monthlyAllowance {
            usedThisPeriod += 1
            return .monthly
        }
        if topUps > 0 {
            topUps -= 1
            return .topUp
        }
        usedThisPeriod += 1
        return .over
    }

    /// A Brief arrived: count it. The device's free first check (or one the
    /// proxy marked free) costs nothing.
    @discardableResult
    public mutating func commit(_ state: MembershipState, now: Date, wasFreeOnProxy: Bool = false, rules: PlanRules = .current, calendar: Calendar = .current) -> Spent {
        roll(state, now: now, rules: rules, calendar: calendar)
        if !firstFreeUsed || wasFreeOnProxy {
            firstFreeUsed = true
            return .firstFree
        }
        return spendOne(state)
    }

    /// A top-up was bought. Idempotent per transaction.
    @discardableResult
    public mutating func creditTopUp(transactionID: String, checks: Int = MembershipProduct.topUpChecks) -> Bool {
        guard !creditedTransactions.contains(transactionID) else { return false }
        creditedTransactions.append(transactionID)
        topUps += checks
        return true
    }
}
