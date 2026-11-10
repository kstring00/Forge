import Foundation

/// Decision 0042: every number behind checks, in one place. The defaults here
/// are what ships; the proxy's config (proxy/config/hunch.ts) can send newer
/// ones, which the app saves and uses (decision 0042, G).
public struct PlanRules: Codable, Equatable, Sendable {
    /// What each thing costs, in checks. Researching an idea is the only
    /// thing that costs; everything on a checked idea is included.
    public struct Costs: Codable, Equatable, Sendable {
        /// The panel's first look at an idea: research, scores, the Brief.
        public var check: Int
        /// New web research on an idea that was already checked.
        public var freshRecheck: Int
        public var launchPlan: Int
        public var launchPlanUpdate: Int
        /// The panelists score again after a logged conversation.
        public var rescore: Int
        public var tank: Int

        public init(check: Int = 1, freshRecheck: Int = 1, launchPlan: Int = 0, launchPlanUpdate: Int = 0, rescore: Int = 0, tank: Int = 0) {
            self.check = check
            self.freshRecheck = freshRecheck
            self.launchPlan = launchPlan
            self.launchPlanUpdate = launchPlanUpdate
            self.rescore = rescore
            self.tank = tank
        }
    }

    /// Quiet daily limits on included follow-ups, per idea. Reaching one shows
    /// a friendly line, never the paywall.
    public struct FairUse: Codable, Equatable, Sendable {
        /// New plans and updates together.
        public var launchPlansPerIdeaPerDay: Int
        public var rescoresPerIdeaPerDay: Int
        public var tankRunsPerIdeaPerDay: Int

        public init(launchPlansPerIdeaPerDay: Int = 3, rescoresPerIdeaPerDay: Int = 10, tankRunsPerIdeaPerDay: Int = 3) {
            self.launchPlansPerIdeaPerDay = launchPlansPerIdeaPerDay
            self.rescoresPerIdeaPerDay = rescoresPerIdeaPerDay
            self.tankRunsPerIdeaPerDay = tankRunsPerIdeaPerDay
        }
    }

    /// Unused monthly checks carry into the next cycle (decision 0042, F).
    public struct Rollover: Codable, Equatable, Sendable {
        public var enabled: Bool
        /// How much can carry, in months of allowance. 1 = up to one month's.
        public var capMonths: Int

        public init(enabled: Bool = true, capMonths: Int = 1) {
            self.enabled = enabled
            self.capMonths = capMonths
        }
    }

    /// Checks a month, by plan ("free", "plus", "pro").
    public var monthlyChecks: [String: Int]
    /// Plus's free trial is capped at this many checks.
    public var trialChecks: Int
    /// Checks in one top-up.
    public var topUpChecks: Int
    public var costs: Costs
    public var fairUse: FairUse
    public var rollover: Rollover

    public static let defaultMonthlyChecks = ["free": 1, "plus": 15, "pro": 60]

    public init(monthlyChecks: [String: Int] = PlanRules.defaultMonthlyChecks, trialChecks: Int = 5, topUpChecks: Int = 5,
                costs: Costs = Costs(), fairUse: FairUse = FairUse(), rollover: Rollover = Rollover()) {
        self.monthlyChecks = monthlyChecks
        self.trialChecks = trialChecks
        self.topUpChecks = topUpChecks
        self.costs = costs
        self.fairUse = fairUse
        self.rollover = rollover
    }

    public func monthlyChecks(for plan: Plan) -> Int {
        monthlyChecks[plan.rawValue] ?? Self.defaultMonthlyChecks[plan.rawValue] ?? 0
    }

    /// Rules saved by an older app have fewer sections; missing ones are the defaults.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        monthlyChecks = try c.decodeIfPresent([String: Int].self, forKey: .monthlyChecks) ?? Self.defaultMonthlyChecks
        trialChecks = try c.decodeIfPresent(Int.self, forKey: .trialChecks) ?? 5
        topUpChecks = try c.decodeIfPresent(Int.self, forKey: .topUpChecks) ?? 5
        costs = try c.decodeIfPresent(Costs.self, forKey: .costs) ?? Costs()
        fairUse = try c.decodeIfPresent(FairUse.self, forKey: .fairUse) ?? FairUse()
        rollover = try c.decodeIfPresent(Rollover.self, forKey: .rollover) ?? Rollover()
    }

    /// The rules in force. The app replaces this with the proxy's on launch.
    nonisolated(unsafe) public static var current = PlanRules()

    /// "1 check", "2 checks", "Included".
    public static func label(checks: Int) -> String {
        checks <= 0 ? "Included" : "\(checks) \(checks == 1 ? "check" : "checks")"
    }
}

/// Things done on an idea that has been checked. Included, under fair use.
public enum FollowUp: String, Codable, CaseIterable, Sendable {
    case launchPlan, launchPlanUpdate, rescore, tank

    public func cost(_ rules: PlanRules = .current) -> Int {
        switch self {
        case .launchPlan: rules.costs.launchPlan
        case .launchPlanUpdate: rules.costs.launchPlanUpdate
        case .rescore: rules.costs.rescore
        case .tank: rules.costs.tank
        }
    }

    public func dailyLimit(_ rules: PlanRules = .current) -> Int {
        switch self {
        case .launchPlan, .launchPlanUpdate: rules.fairUse.launchPlansPerIdeaPerDay
        case .rescore: rules.fairUse.rescoresPerIdeaPerDay
        case .tank: rules.fairUse.tankRunsPerIdeaPerDay
        }
    }

    /// New plans and updates share one count.
    var counter: String {
        switch self {
        case .launchPlan, .launchPlanUpdate: "plan"
        case .rescore: "rescore"
        case .tank: "tank"
        }
    }

    /// What someone at the limit reads. Friendly, never the paywall.
    public var limitMessage: String {
        switch self {
        case .launchPlan, .launchPlanUpdate:
            "That's today's plans for this idea. Plans are included, just paced: it's ready for another tomorrow."
        case .rescore:
            "That's today's re-scores for this idea. What you logged is saved; the panel can look again tomorrow."
        case .tank:
            "That's today's Tank runs for this idea. It's included, just paced: back tomorrow."
        }
    }
}

/// Counts included follow-ups per idea per day, on whatever does the counting
/// (the phone today, the proxy ledger later). Keeps today only.
public struct FairUseLedger: Codable, Equatable, Sendable {
    public var day: String
    public var counts: [String: Int]

    public init(day: String = "", counts: [String: Int] = [:]) {
        self.day = day
        self.counts = counts
    }

    static func dayKey(_ now: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: now)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func key(_ kind: FollowUp, _ ideaID: UUID) -> String { "\(ideaID.uuidString)|\(kind.counter)" }

    public func used(_ kind: FollowUp, ideaID: UUID, now: Date, calendar: Calendar = .current) -> Int {
        day == Self.dayKey(now, calendar: calendar) ? counts[Self.key(kind, ideaID)] ?? 0 : 0
    }

    public func canUse(_ kind: FollowUp, ideaID: UUID, now: Date, rules: PlanRules = .current, calendar: Calendar = .current) -> Bool {
        used(kind, ideaID: ideaID, now: now, calendar: calendar) < kind.dailyLimit(rules)
    }

    /// One more, today. A new day starts from zero.
    public mutating func record(_ kind: FollowUp, ideaID: UUID, now: Date, calendar: Calendar = .current) {
        let today = Self.dayKey(now, calendar: calendar)
        if day != today {
            day = today
            counts = [:]
        }
        counts[Self.key(kind, ideaID), default: 0] += 1
    }
}
