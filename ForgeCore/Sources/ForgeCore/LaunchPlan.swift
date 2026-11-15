import Foundation

/// Decision 0041: a launch plan. Short, built only from what Hunch knows about
/// one idea: what the world has shown, what is still a belief, three 30-day
/// blocks that each end in a decision rule, the money as price × customers ×
/// share, and when to stop. Saved on the idea; refreshed only when asked.
public struct LaunchPlan: Codable, Equatable, Sendable {
    /// Something the world has shown, and the Library source that shows it.
    public struct Claim: Codable, Equatable, Sendable {
        public var text: String
        public var sourceID: UUID?

        public init(text: String, sourceID: UUID?) {
            self.text = text
            self.sourceID = sourceID
        }
    }

    /// One 30-day block: what to do, and the rule that decides what comes next.
    public struct Phase: Codable, Equatable, Sendable {
        /// "Days 1–30"
        public var days: String
        public var title: String
        public var detail: String
        /// "If 2 of 3 say yes, build the first batch."
        public var decide: String

        public init(days: String, title: String, detail: String, decide: String) {
            self.days = days
            self.title = title
            self.detail = detail
            self.decide = decide
        }
    }

    /// What the plan was built on, so the plan page can say what changed since.
    public struct Basis: Codable, Equatable, Sendable {
        /// Conversations logged on the idea.
        public var conversations: Int
        /// Where proof was on the four-step ladder: -1 none, 0 looked up online … 3 came back.
        public var proofStep: Int
        /// When the panel last looked.
        public var checkedAt: Date?

        public init(conversations: Int, proofStep: Int, checkedAt: Date?) {
            self.conversations = conversations
            self.proofStep = proofStep
            self.checkedAt = checkedAt
        }
    }

    public var oneLine: String
    public var forWho: String
    public var proven: [Claim]
    public var unproven: [String]
    public var riskiest: String
    /// Three blocks: days 1–30, 31–60, 61–90.
    public var phases: [Phase]
    /// "clinics": one paying customer, plural, for the money line.
    public var customerNoun: String
    public var stopRule: String
    public var stewardNote: String?
    public var rationale: String
    public var createdAt: Date
    public var basis: Basis

    public init(oneLine: String, forWho: String, proven: [Claim], unproven: [String], riskiest: String, phases: [Phase],
                customerNoun: String, stopRule: String, stewardNote: String?, rationale: String, createdAt: Date, basis: Basis) {
        self.oneLine = oneLine
        self.forWho = forWho
        self.proven = proven
        self.unproven = unproven
        self.riskiest = riskiest
        self.phases = phases
        self.customerNoun = customerNoun
        self.stopRule = stopRule
        self.stewardNote = stewardNote
        self.rationale = rationale
        self.createdAt = createdAt
        self.basis = basis
    }

    public static let dayLabels = ["Days 1–30", "Days 31–60", "Days 61–90"]

    /// "2 more conversations", "proof moved up a step", "a newer panel take".
    /// Empty when nothing has moved since the plan was made.
    public static func changes(from old: Basis, to new: Basis) -> [String] {
        var out: [String] = []
        let more = new.conversations - old.conversations
        if more > 0 { out.append("\(more) more \(more == 1 ? "conversation" : "conversations")") }
        let up = new.proofStep - old.proofStep
        if up > 0 { out.append(up == 1 ? "proof moved up a step" : "proof moved up \(up) steps") }
        if let n = new.checkedAt, n > (old.checkedAt ?? .distantPast).addingTimeInterval(60) { out.append("a newer panel take") }
        return out
    }
}

/// What a plan costs (decision 0042): included on every plan once the idea
/// has been checked, new or brought up to date, under the fair-use limit.
/// The numbers live in `PlanRules`.
public enum PlanCost {
    public static func checks(on plan: Plan, refreshing: Bool, rules: PlanRules = .current) -> Int {
        (refreshing ? FollowUp.launchPlanUpdate : .launchPlan).cost(rules)
    }

    /// "Included", or "1 check" if the rules ever charge for it.
    public static func label(on plan: Plan, refreshing: Bool, rules: PlanRules = .current) -> String {
        PlanRules.label(checks: checks(on: plan, refreshing: refreshing, rules: rules))
    }
}

/// The money line on a plan: the middle of each input, so a person can follow
/// the arithmetic. "$40 × 30 clinics × 20% = $240 / mo".
public struct PlanMoney: Equatable, Sendable {
    public var price: Double
    public var customers: Int
    /// 0 to 1.
    public var share: Double
    public var priceIsAssumption: Bool
    public var customersIsAssumption: Bool
    public var shareIsAssumption: Bool

    public var monthly: Double { price * Double(customers) * share }

    /// Nil when the estimate itself says it is too early (no price found).
    public init?(_ inputs: ReturnInputs) {
        guard case .range = inputs.outcome else { return nil }
        func mid(_ i: ReturnInputs.Input) -> Double { (i.low + i.high) / 2 }
        let p = mid(inputs.price)
        price = p >= 20 ? (p / 5).rounded() * 5 : p.rounded()
        customers = max(1, Int(mid(inputs.reachable).rounded()))
        share = (mid(inputs.conversion) * 100).rounded() / 100
        priceIsAssumption = inputs.price.isAssumption
        customersIsAssumption = inputs.reachable.isAssumption
        shareIsAssumption = inputs.conversion.isAssumption
        guard price > 0, share > 0 else { return nil }
    }

    /// "20%"
    public var sharePercent: String { "\(Int((share * 100).rounded()))%" }
}

extension CheckLedger {
    /// Whether `checks` monthly or bought checks are there to spend at once
    /// while `inFlight` single checks are already running. The free first
    /// check is not counted: it is for a panel take.
    public func canSpend(_ checks: Int, _ state: MembershipState, now: Date, inFlight: Int = 0, calendar: Calendar = .current) -> Bool {
        guard checks > 0 else { return true }
        return balance(state, now: now, calendar: calendar).total - inFlight >= checks
    }

    /// Spend `checks` at once: carried-over, monthly, then bought. Called only
    /// when what they paid for arrived.
    public mutating func spend(_ checks: Int, _ state: MembershipState, now: Date, calendar: Calendar = .current) {
        roll(state, now: now, calendar: calendar)
        for _ in 0..<max(0, checks) { _ = spendOne(state, now: now) }
    }
}

/// The plan as a printable page (HTML the app turns into a PDF). Pure, so the
/// words on paper are tested with the rest of the core.
public enum LaunchPlanDocument {
    public struct Input: Sendable {
        public var title: String
        public var plan: LaunchPlan
        public var potential: String?
        public var proof: String?
        public var nextStep: String?
        public var money: PlanMoney?
        /// Shown instead of the money line when there is no figure.
        public var moneyNote: String?
        public var sourceTitles: [UUID: String]
        /// "November 9, 2026"
        public var dateText: String

        public init(title: String, plan: LaunchPlan, potential: String?, proof: String?, nextStep: String?, money: PlanMoney?,
                    moneyNote: String?, sourceTitles: [UUID: String], dateText: String) {
            self.title = title
            self.plan = plan
            self.potential = potential
            self.proof = proof
            self.nextStep = nextStep
            self.money = money
            self.moneyNote = moneyNote
            self.sourceTitles = sourceTitles
            self.dateText = dateText
        }
    }

    public static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// "$40", "$1.2k"
    public static func dollars(_ v: Double) -> String { Projection.compact(v) }

    public static func html(_ i: Input) -> String {
        let e = escape
        let p = i.plan
        var body = ""
        body += "<p class=\"label\">Launch plan · \(e(i.dateText))</p>"
        body += "<h1>\(e(i.title))</h1>"
        body += "<p class=\"lede\">\(e(p.oneLine))</p>"

        var meters: [String] = []
        if let potential = i.potential { meters.append("<td><p class=\"label\">Potential</p><p class=\"big\">\(e(potential))</p><p class=\"small\">the panel's view</p></td>") }
        if let proof = i.proof {
            let next = i.nextStep.map { "<p class=\"small\">Next: \(e($0))</p>" } ?? ""
            meters.append("<td><p class=\"label\">Proof</p><p class=\"big\">\(e(proof))</p>\(next)</td>")
        }
        if !meters.isEmpty { body += "<table class=\"meters\"><tr>\(meters.joined())</tr></table>" }

        body += section("Who it's for", "<p>\(e(p.forWho))</p>")

        var proof = "<ul class=\"proof\">"
        for c in p.proven {
            let src = c.sourceID.flatMap { i.sourceTitles[$0] }.map { " <span class=\"src\">(\(e($0)))</span>" } ?? ""
            proof += "<li class=\"solid\">\(e(c.text))\(src)</li>"
        }
        for t in p.unproven { proof += "<li class=\"hollow\">\(e(t))</li>" }
        proof += "</ul><p><strong>The riskiest belief:</strong> \(e(p.riskiest))</p>"
        body += section("What's proven · what isn't", proof)

        var days = "<table class=\"days\">"
        for ph in p.phases {
            days += "<tr><td class=\"when\">\(e(ph.days))</td><td><p class=\"phase\">\(e(ph.title))</p><p>\(e(ph.detail))</p><p class=\"small\">Decide: \(e(ph.decide))</p></td></tr>"
        }
        days += "</table>"
        body += section("First 90 days", days)

        if let m = i.money {
            func mark(_ assumption: Bool) -> String { assumption ? " <span class=\"src\">(assumption)</span>" : "" }
            body += section("The money", """
            <p class="money">\(e(dollars(m.price))) × \(m.customers) \(e(p.customerNoun)) × \(e(m.sharePercent)) = \(e(dollars(m.monthly))) / mo</p>
            <p class="small">Price\(mark(m.priceIsAssumption)) · customers in year one\(mark(m.customersIsAssumption)) · share who pay\(mark(m.shareIsAssumption)). The middle of the panel's estimate, not a promise.</p>
            """)
        } else if let note = i.moneyNote {
            body += section("The money", "<p>\(e(note))</p>")
        }

        body += section("When to stop", "<p>\(e(p.stopRule))</p>")
        if let s = p.stewardNote, !s.isEmpty { body += section("Your charter", "<p>\(e(s))</p>") }
        body += "<p class=\"foot\">Made with Hunch. Solid dots are things people or sources have shown; hollow dots are still beliefs. Every figure is an estimate until someone pays.</p>"

        return """
        <!doctype html><html><head><meta charset="utf-8"><style>
        body { font-family: -apple-system, Helvetica, sans-serif; color: #1C1916; font-size: 11pt; line-height: 1.45; margin: 0; }
        h1 { font-family: Georgia, serif; font-size: 26pt; margin: 2pt 0 4pt; }
        h2 { font-family: Menlo, monospace; font-size: 8.5pt; letter-spacing: 1.5pt; text-transform: uppercase; color: #6B635A; margin: 18pt 0 6pt; border-top: 0.5pt solid #D9D2C7; padding-top: 10pt; }
        p { margin: 0 0 4pt; }
        .label { font-family: Menlo, monospace; font-size: 8pt; letter-spacing: 1.5pt; text-transform: uppercase; color: #6B635A; }
        .lede { font-size: 12.5pt; color: #3A342E; }
        .meters { width: 100%; border-collapse: separate; border-spacing: 8pt 0; margin: 10pt -8pt 0; }
        .meters td { border: 0.5pt solid #D9D2C7; border-radius: 8pt; padding: 8pt 10pt; vertical-align: top; width: 50%; }
        .big { font-family: Georgia, serif; font-size: 16pt; margin: 2pt 0; }
        .small { font-size: 9pt; color: #6B635A; }
        .proof { list-style: none; padding: 0; margin: 0 0 6pt; }
        .proof li { padding-left: 16pt; position: relative; margin-bottom: 4pt; }
        .proof li.solid::before { content: "●"; position: absolute; left: 0; color: #C4441C; }
        .proof li.hollow::before { content: "○"; position: absolute; left: 0; color: #6B635A; }
        .src { color: #6B635A; font-size: 9pt; }
        .days { width: 100%; border-collapse: collapse; }
        .days td { vertical-align: top; padding: 4pt 0 8pt; }
        .when { font-family: Menlo, monospace; font-size: 8.5pt; color: #6B635A; width: 80pt; padding-top: 6pt; }
        .phase { font-family: Georgia, serif; font-size: 13pt; margin-bottom: 2pt; }
        .money { font-family: Georgia, serif; font-size: 16pt; }
        .foot { margin-top: 22pt; font-size: 8.5pt; color: #6B635A; }
        </style></head><body>\(body)</body></html>
        """
    }

    private static func section(_ title: String, _ inner: String) -> String {
        "<h2>\(escape(title))</h2>\(inner)"
    }
}
