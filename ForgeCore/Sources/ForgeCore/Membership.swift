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

    /// Apple's level in the group: 1 is the highest. Pro ranks above Plus;
    /// the founding price is Plus. Keep App Store Connect the same.
    public static func level(_ productID: String) -> Int? {
        switch productID {
        case proMonthly, proYearly: 1
        case plusMonthly, plusYearly, plusFoundingYearly: 2
        default: nil
        }
    }

    public static func isYearly(_ productID: String) -> Bool {
        [plusYearly, plusFoundingYearly, proYearly].contains(productID)
    }

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

/// What the App Store says about this person right now. Built only from
/// StoreKit's current entitlement and its renewal info (`init(entitlement:)`),
/// never from the latest transaction or a saved flag alone.
public struct MembershipState: Codable, Equatable, Sendable {
    public var plan: Plan
    /// In Plus's 7-day free trial: checks are capped at `trialChecks`.
    public var isTrial: Bool
    /// When the current billing period began: the entitled transaction's
    /// purchase date. Monthly checks reset on its day of the month, yearly
    /// plans included. An upgrade or a switch at renewal is a new transaction,
    /// so it moves this. Nil on Free, which resets on the 1st.
    public var anchor: Date?
    public var productID: String?
    /// When the current billing period ends (the transaction's expiration date).
    public var renewsAt: Date?
    public var founding: Bool
    /// The entitled transaction, recorded with every grant and carry.
    public var transactionID: String?
    /// False once the person has cancelled: the plan runs to `renewsAt`, then Free.
    public var willAutoRenew: Bool
    /// A switch Apple has booked for the next renewal (a downgrade, or monthly ↔
    /// yearly). Nil when it renews as it is.
    public var nextProductID: String?
    public var billing: BillingStatus
    /// Shared by a family organizer (only if Family Sharing is turned on).
    public var familyShared: Bool

    /// Plus's trial cap, from the rules in force (decision 0042).
    public static var trialChecks: Int { PlanRules.current.trialChecks }
    public static let free = MembershipState(plan: .free, isTrial: false, anchor: nil, productID: nil, renewsAt: nil, founding: false)

    public init(plan: Plan, isTrial: Bool, anchor: Date?, productID: String?, renewsAt: Date?, founding: Bool,
                transactionID: String? = nil, willAutoRenew: Bool = true, nextProductID: String? = nil,
                billing: BillingStatus = .ok, familyShared: Bool = false) {
        self.plan = plan
        self.isTrial = isTrial
        self.anchor = anchor
        self.productID = productID
        self.renewsAt = renewsAt
        self.founding = founding
        self.transactionID = transactionID
        self.willAutoRenew = willAutoRenew
        self.nextProductID = nextProductID
        self.billing = billing
        self.familyShared = familyShared
    }

    /// States saved before decision 0043 have none of the renewal fields.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        plan = try c.decode(Plan.self, forKey: .plan)
        isTrial = try c.decodeIfPresent(Bool.self, forKey: .isTrial) ?? false
        anchor = try c.decodeIfPresent(Date.self, forKey: .anchor)
        productID = try c.decodeIfPresent(String.self, forKey: .productID)
        renewsAt = try c.decodeIfPresent(Date.self, forKey: .renewsAt)
        founding = try c.decodeIfPresent(Bool.self, forKey: .founding) ?? false
        transactionID = try c.decodeIfPresent(String.self, forKey: .transactionID)
        willAutoRenew = try c.decodeIfPresent(Bool.self, forKey: .willAutoRenew) ?? true
        nextProductID = try c.decodeIfPresent(String.self, forKey: .nextProductID)
        billing = try c.decodeIfPresent(BillingStatus.self, forKey: .billing) ?? .ok
        familyShared = try c.decodeIfPresent(Bool.self, forKey: .familyShared) ?? false
    }

    public var monthlyAllowance: Int { isTrial ? min(Self.trialChecks, plan.monthlyChecks) : plan.monthlyChecks }

    /// The plan Apple has booked for the next renewal, when it differs.
    public var nextPlan: Plan? { nextProductID.flatMap(MembershipProduct.plan(for:)) }
    /// Cancelled: runs to `renewsAt`, then Free.
    public var isCancelled: Bool { plan != .free && !willAutoRenew }
    public var isYearly: Bool { productID.map(MembershipProduct.isYearly) ?? false }
}

/// Apple's billing state for the subscription (decision 0043).
public enum BillingStatus: Codable, Equatable, Sendable {
    case ok
    /// A renewal payment failed; Apple keeps the plan active until `until`
    /// while it retries (the billing grace period).
    case gracePeriod(until: Date?)
    /// A renewal payment failed and there is no grace left: the plan is
    /// paused (Free) until the payment goes through.
    case retrying(productID: String?)

    public var hasIssue: Bool { self != .ok }
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

    /// Decision 0043: the check cycle containing `now` for this state, as
    /// (start, end). The billing period (anchor → renewsAt) is split into
    /// monthly cycles on the anchor's day: one for a monthly plan, twelve for
    /// a yearly one (bought on the 31st → the last day of shorter months).
    /// Past `renewsAt` (Apple's grace period, or before the App Store has
    /// told the app about a renewal) the last cycle carries on: no new
    /// allowance until Apple says the plan renewed. Without `renewsAt`, the
    /// anchor's monthly anniversaries run on.
    public static func cycle(containing now: Date, for state: MembershipState, calendar: Calendar = .current) -> (start: Date, end: Date) {
        guard state.plan != .free, let anchor = state.anchor else {
            let s = start(containing: now, anchor: nil, calendar: calendar)
            return (s, nextReset(after: now, anchor: nil, calendar: calendar))
        }
        guard let end = state.renewsAt, end > anchor else {
            let s = start(containing: now, anchor: anchor, calendar: calendar)
            return (s, nextReset(after: now, anchor: anchor, calendar: calendar))
        }
        let bounds = boundaries(anchor: anchor, end: end, yearly: state.isYearly && !state.isTrial, calendar: calendar)
        guard now >= anchor else { return (anchor, bounds.first ?? end) }
        var s = anchor
        for b in bounds {
            if b <= now { s = b } else { return (s, b) }
        }
        return (s, end)
    }

    /// Cycle starts inside one billing period, after the anchor; the last
    /// cycle ends at `end`. A yearly period that the StoreKit test clock
    /// shortened to minutes is split into twelve equal parts, so the
    /// simulator shows monthly checks arriving on a yearly plan.
    static func boundaries(anchor: Date, end: Date, yearly: Bool, calendar: Calendar) -> [Date] {
        let span = end.timeIntervalSince(anchor)
        if span >= 300 * 86_400 || !yearly {
            var out: [Date] = []
            var k = 1
            while let b = calendar.date(byAdding: .month, value: k, to: anchor), b < end.addingTimeInterval(-3 * 86_400) {
                out.append(b)
                k += 1
            }
            return out
        }
        return (1..<12).map { anchor.addingTimeInterval(span * Double($0) / 12) }
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

/// One bought top-up and how many of its checks are left. Spent oldest first,
/// so a refund takes back only that purchase's unused checks.
public struct TopUpLot: Codable, Equatable, Sendable {
    public var transactionID: String
    public var checks: Int
    public var remaining: Int

    public init(transactionID: String, checks: Int, remaining: Int) {
        self.transactionID = transactionID
        self.checks = checks
        self.remaining = remaining
    }
}

/// Decision 0043: everything that changed a balance, in order, with the App
/// Store transaction behind it. The server ledger (#22) can rebuild a balance
/// from these and then take over from App Store Server Notifications.
public struct LedgerEvent: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// A cycle began with this many monthly checks.
        case grant
        /// Unused checks carried into the new cycle.
        case carry
        /// Checks that ran out unused: carried ones at the end of their cycle,
        /// or monthly ones past the carry cap.
        case expire
        /// One check spent; `bucket` says from where.
        case spend
        case topUp
        /// A refunded top-up: its unused checks, removed.
        case topUpRefund
        /// The plan changed inside a cycle (a trial ended on the same product).
        case planChange
    }

    public var id: String
    public var at: Date
    public var kind: Kind
    public var checks: Int
    public var plan: Plan
    /// The App Store transaction (subscription or top-up) this came from.
    public var transactionID: String?
    /// For `spend`: firstFree, rolledOver, monthly, topUp or over.
    public var bucket: String?

    public init(id: String = UUID().uuidString, at: Date, kind: Kind, checks: Int, plan: Plan, transactionID: String? = nil, bucket: String? = nil) {
        self.id = id
        self.at = at
        self.kind = kind
        self.checks = checks
        self.plan = plan
        self.transactionID = transactionID
        self.bucket = bucket
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
///
/// Decision 0043: a cycle is a monthly slice of the App Store billing period
/// (`CheckPeriod.cycle`), so an upgrade, a switch at renewal, a trial turning
/// paid, a lapse and a resubscribe each start a new cycle with the carry rules
/// above. Bought checks are kept per purchase (`topUpLots`), and every change
/// is recorded in `events`.
public struct CheckLedger: Codable, Equatable, Sendable {
    public var periodStart: Date
    public var usedThisPeriod: Int
    /// Bought checks left: always the sum of `topUpLots`.
    public private(set) var topUps: Int
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
    /// Bought checks, per purchase, oldest first.
    public private(set) var topUpLots: [TopUpLot]
    /// The most recent `eventLimit` changes, oldest first.
    public private(set) var events: [LedgerEvent]

    public static let eventLimit = 1000
    /// A lot for bought checks counted before decision 0043 kept them per purchase.
    static let legacyLot = "legacy"

    public enum Spent: String, Equatable, Sendable { case firstFree, rolledOver, monthly, topUp, over }

    public init(periodStart: Date = .distantPast, usedThisPeriod: Int = 0, topUps: Int = 0, firstFreeUsed: Bool = false, creditedTransactions: [String] = [],
                rolledOver: Int = 0, rolledOverUsed: Int = 0, allowanceThisPeriod: Int? = nil, periodWasTrial: Bool = false, periodEnd: Date? = nil) {
        self.periodStart = periodStart
        self.usedThisPeriod = usedThisPeriod
        self.firstFreeUsed = firstFreeUsed
        self.creditedTransactions = creditedTransactions
        self.rolledOver = rolledOver
        self.rolledOverUsed = rolledOverUsed
        self.allowanceThisPeriod = allowanceThisPeriod
        self.periodWasTrial = periodWasTrial
        self.periodEnd = periodEnd
        self.topUpLots = topUps > 0 ? [TopUpLot(transactionID: Self.legacyLot, checks: topUps, remaining: topUps)] : []
        self.topUps = topUps
        self.events = []
    }

    /// Ledgers saved before rollover (0042) or per-purchase top-ups (0043) lack their fields.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        periodStart = try c.decodeIfPresent(Date.self, forKey: .periodStart) ?? .distantPast
        usedThisPeriod = try c.decodeIfPresent(Int.self, forKey: .usedThisPeriod) ?? 0
        firstFreeUsed = try c.decodeIfPresent(Bool.self, forKey: .firstFreeUsed) ?? false
        creditedTransactions = try c.decodeIfPresent([String].self, forKey: .creditedTransactions) ?? []
        rolledOver = try c.decodeIfPresent(Int.self, forKey: .rolledOver) ?? 0
        rolledOverUsed = try c.decodeIfPresent(Int.self, forKey: .rolledOverUsed) ?? 0
        allowanceThisPeriod = try c.decodeIfPresent(Int.self, forKey: .allowanceThisPeriod)
        periodWasTrial = try c.decodeIfPresent(Bool.self, forKey: .periodWasTrial) ?? false
        periodEnd = try c.decodeIfPresent(Date.self, forKey: .periodEnd)
        events = try c.decodeIfPresent([LedgerEvent].self, forKey: .events) ?? []
        let saved = try c.decodeIfPresent(Int.self, forKey: .topUps) ?? 0
        var lots = try c.decodeIfPresent([TopUpLot].self, forKey: .topUpLots) ?? []
        let inLots = lots.reduce(0) { $0 + $1.remaining }
        if saved > inLots { lots.insert(TopUpLot(transactionID: Self.legacyLot, checks: saved - inLots, remaining: saved - inLots), at: 0) }
        topUpLots = lots
        topUps = lots.reduce(0) { $0 + $1.remaining }
    }

    private mutating func log(_ kind: LedgerEvent.Kind, _ checks: Int, _ state: MembershipState, at: Date, transactionID: String? = nil, bucket: String? = nil) {
        events.append(LedgerEvent(at: at, kind: kind, checks: checks, plan: state.plan, transactionID: transactionID ?? state.transactionID, bucket: bucket))
        if events.count > Self.eventLimit { events.removeFirst(events.count - Self.eventLimit) }
    }

    private mutating func syncTopUps() { topUps = topUpLots.reduce(0) { $0 + $1.remaining } }

    /// What carries from the cycle that just ended into one that starts at
    /// `newStart` on `state`. A whole cycle passing unseen in between means
    /// that cycle's allowance went unused.
    func carry(into state: MembershipState, newStart: Date, rules: PlanRules) -> Int {
        guard rules.rollover.enabled, periodStart != .distantPast, !periodWasTrial, !state.isTrial else { return 0 }
        return min(unusedAtEnd(newStart: newStart, fallback: state.monthlyAllowance), carryCap(into: state, rules: rules))
    }

    private func unusedAtEnd(newStart: Date, fallback: Int) -> Int {
        let oldAllowance = allowanceThisPeriod ?? fallback
        let skippedACycle = periodEnd.map { newStart >= $0.addingTimeInterval(25 * 86_400) } ?? false
        return skippedACycle ? oldAllowance : max(0, oldAllowance - usedThisPeriod)
    }

    private func carryCap(into state: MembershipState, rules: PlanRules) -> Int {
        min(allowanceThisPeriod ?? state.monthlyAllowance, state.monthlyAllowance) * max(0, rules.rollover.capMonths)
    }

    /// A new cycle starts with no monthly checks used and last cycle's unused
    /// ones carried over. Bought checks stay.
    public mutating func roll(_ state: MembershipState, now: Date, rules: PlanRules = .current, calendar: Calendar = .current) {
        let cycle = CheckPeriod.cycle(containing: now, for: state, calendar: calendar)
        if cycle.start != periodStart {
            let started = periodStart != .distantPast
            let carried = carry(into: state, newStart: cycle.start, rules: rules)
            if started {
                let carriedLeft = max(0, rolledOver - rolledOverUsed)
                let lapsed = max(0, unusedAtEnd(newStart: cycle.start, fallback: state.monthlyAllowance) - carried)
                if carriedLeft + lapsed > 0 { log(.expire, carriedLeft + lapsed, state, at: now) }
                if carried > 0 { log(.carry, carried, state, at: now) }
            }
            rolledOver = carried
            rolledOverUsed = 0
            periodStart = cycle.start
            usedThisPeriod = 0
            periodEnd = cycle.end
            log(.grant, state.monthlyAllowance, state, at: now)
        } else if allowanceThisPeriod != state.monthlyAllowance {
            // Within a cycle the plan can change without a new transaction.
            log(.planChange, state.monthlyAllowance, state, at: now)
        }
        allowanceThisPeriod = state.monthlyAllowance
        periodWasTrial = state.isTrial
        periodEnd = cycle.end
    }

    public func balance(_ state: MembershipState, now: Date, rules: PlanRules = .current, calendar: Calendar = .current) -> CheckBalance {
        var l = self
        l.roll(state, now: now, rules: rules, calendar: calendar)
        let allowance = state.monthlyAllowance
        return CheckBalance(monthlyLeft: max(0, allowance - l.usedThisPeriod), monthlyAllowance: allowance,
                            rolledOverLeft: max(0, l.rolledOver - l.rolledOverUsed), topUps: l.topUps,
                            resetsAt: CheckPeriod.cycle(containing: now, for: state, calendar: calendar).end,
                            firstFreeAvailable: !l.firstFreeUsed, plan: state.plan, isTrial: state.isTrial)
    }

    /// Whether one more check may start while `inFlight` are already running.
    public func canStart(_ state: MembershipState, now: Date, inFlight: Int = 0, rules: PlanRules = .current, calendar: Calendar = .current) -> Bool {
        let b = balance(state, now: now, rules: rules, calendar: calendar)
        let available = b.total + (b.firstFreeAvailable ? 1 : 0)
        return available - inFlight > 0
    }

    /// Spends one check in order: carried-over, this month's, bought (oldest purchase first).
    mutating func spendOne(_ state: MembershipState, now: Date) -> Spent {
        var lot: String?
        let spent: Spent
        if rolledOverUsed < rolledOver {
            rolledOverUsed += 1
            spent = .rolledOver
        } else if usedThisPeriod < state.monthlyAllowance {
            usedThisPeriod += 1
            spent = .monthly
        } else if let i = topUpLots.firstIndex(where: { $0.remaining > 0 }) {
            topUpLots[i].remaining -= 1
            lot = topUpLots[i].transactionID
            syncTopUps()
            spent = .topUp
        } else {
            // A check that was already running when the balance hit zero.
            usedThisPeriod += 1
            spent = .over
        }
        log(.spend, 1, state, at: now, transactionID: lot, bucket: spent.rawValue)
        return spent
    }

    /// A Brief arrived: count it. The device's free first check (or one the
    /// proxy marked free) costs nothing.
    @discardableResult
    public mutating func commit(_ state: MembershipState, now: Date, wasFreeOnProxy: Bool = false, rules: PlanRules = .current, calendar: Calendar = .current) -> Spent {
        roll(state, now: now, rules: rules, calendar: calendar)
        if !firstFreeUsed || wasFreeOnProxy {
            firstFreeUsed = true
            log(.spend, 1, state, at: now, bucket: Spent.firstFree.rawValue)
            return .firstFree
        }
        return spendOne(state, now: now)
    }

    /// A top-up was bought. Idempotent per transaction.
    @discardableResult
    public mutating func creditTopUp(transactionID: String, checks: Int = MembershipProduct.topUpChecks, now: Date = Date(), plan: Plan = .free) -> Bool {
        guard !creditedTransactions.contains(transactionID) else { return false }
        creditedTransactions.append(transactionID)
        topUpLots.append(TopUpLot(transactionID: transactionID, checks: checks, remaining: checks))
        syncTopUps()
        events.append(LedgerEvent(at: now, kind: .topUp, checks: checks, plan: plan, transactionID: transactionID))
        return true
    }

    /// A top-up was refunded: its unused checks go; spent ones stay spent and
    /// nothing goes below zero. Idempotent. Returns the checks removed.
    @discardableResult
    public mutating func refundTopUp(transactionID: String, now: Date = Date(), plan: Plan = .free) -> Int {
        let refundKey = "refund:" + transactionID
        guard !creditedTransactions.contains(refundKey) else { return 0 }
        creditedTransactions.append(refundKey)
        guard let i = topUpLots.firstIndex(where: { $0.transactionID == transactionID }) else { return 0 }
        let removed = topUpLots[i].remaining
        topUpLots[i].remaining = 0
        syncTopUps()
        events.append(LedgerEvent(at: now, kind: .topUpRefund, checks: removed, plan: plan, transactionID: transactionID))
        return removed
    }
}

extension CheckLedger {
    /// Decision 0043: two copies of one person's ledger (this phone's and the
    /// one in their iCloud) become one. Never adds checks: the later cycle
    /// wins; inside the same cycle the larger count of spent checks wins;
    /// each top-up keeps the fewer checks left; the free first check counts
    /// as used if either copy used it.
    public func merged(with other: CheckLedger) -> CheckLedger {
        var m: CheckLedger
        if other.periodStart > periodStart { m = other }
        else if other.periodStart < periodStart { m = self }
        else {
            m = self
            m.usedThisPeriod = max(usedThisPeriod, other.usedThisPeriod)
            m.rolledOver = min(rolledOver, other.rolledOver)
            m.rolledOverUsed = max(rolledOverUsed, other.rolledOverUsed)
            m.periodEnd = [periodEnd, other.periodEnd].compactMap { $0 }.min()
        }
        m.firstFreeUsed = firstFreeUsed || other.firstFreeUsed
        m.creditedTransactions = creditedTransactions + other.creditedTransactions.filter { !creditedTransactions.contains($0) }
        var lots = topUpLots
        for lot in other.topUpLots {
            if let i = lots.firstIndex(where: { $0.transactionID == lot.transactionID }) {
                lots[i].remaining = min(lots[i].remaining, lot.remaining)
            } else {
                lots.append(lot)
            }
        }
        // A top-up refunded on either copy stays refunded.
        for key in m.creditedTransactions where key.hasPrefix("refund:") {
            let id = String(key.dropFirst("refund:".count))
            if let i = lots.firstIndex(where: { $0.transactionID == id }) { lots[i].remaining = 0 }
        }
        m.topUpLots = lots
        m.syncTopUps()
        var seen = Set<String>()
        m.events = (events + other.events).filter { seen.insert($0.id).inserted }.sorted { $0.at < $1.at }
        if m.events.count > Self.eventLimit { m.events.removeFirst(m.events.count - Self.eventLimit) }
        return m
    }

    /// Restore on a phone with no ledger: top-ups found in the App Store's
    /// history are marked as known, so they are never credited later, but
    /// their checks are not given again: the history can't say how many were
    /// spent (decision 0043). Returns how many were new to this ledger.
    @discardableResult
    public mutating func recordKnownTopUps(_ transactionIDs: [String]) -> Int {
        let new = transactionIDs.filter { !creditedTransactions.contains($0) }
        creditedTransactions += new
        return new.count
    }
}
