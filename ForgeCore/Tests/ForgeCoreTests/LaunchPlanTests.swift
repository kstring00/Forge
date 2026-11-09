import XCTest
@testable import ForgeCore

/// Decision 0041: launch plans: what they cost, how checks are spent at once,
/// the money line, what changed since, and the printed page.
final class LaunchPlanTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private func d(_ y: Int, _ m: Int, _ day: Int) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day, hour: 12))! }
    private func state(_ plan: Plan) -> MembershipState {
        MembershipState(plan: plan, isTrial: false, anchor: plan == .free ? nil : d(2026, 1, 5), productID: nil, renewsAt: nil, founding: false)
    }

    private func plan(basis: LaunchPlan.Basis = .init(conversations: 0, proofStep: 0, checkedAt: nil)) -> LaunchPlan {
        LaunchPlan(oneLine: "Tags for clinics <fast>", forWho: "ABA clinics.",
                   proven: [.init(text: "3 directors said lost cards are weekly", sourceID: UUID())],
                   unproven: ["No clinic has paid yet"], riskiest: "Clinics pay for it",
                   phases: LaunchPlan.dayLabels.map { .init(days: $0, title: "Sell to 3 clinics", detail: "Visit.", decide: "If 2 say yes, build.") },
                   customerNoun: "clinics", stopRule: "If no clinic pays by day 45.", stewardNote: nil,
                   rationale: "", createdAt: d(2026, 11, 1), basis: basis)
    }

    func testAPlanCostsThreeChecksARefreshOneAndProIncludesThem() {
        XCTAssertEqual(PlanCost.checks(on: .free, refreshing: false), 3)
        XCTAssertEqual(PlanCost.checks(on: .plus, refreshing: false), 3)
        XCTAssertEqual(PlanCost.checks(on: .plus, refreshing: true), 1)
        XCTAssertEqual(PlanCost.checks(on: .pro, refreshing: false), 0)
        XCTAssertEqual(PlanCost.label(on: .pro, refreshing: true), "Included in Pro")
        XCTAssertEqual(PlanCost.label(on: .plus, refreshing: false), "3 checks")
        XCTAssertEqual(PlanCost.label(on: .plus, refreshing: true), "1 check")
    }

    func testSpendingThreeChecksTakesMonthlyFirstThenBought() {
        let s = state(.plus)
        let now = d(2026, 11, 9)
        var l = CheckLedger()
        l.usedThisPeriod = 0
        l.roll(s, now: now, calendar: cal)
        l.usedThisPeriod = 13
        l.topUps = 5
        XCTAssertTrue(l.canSpend(3, s, now: now, calendar: cal))
        l.spend(3, s, now: now, calendar: cal)
        XCTAssertEqual(l.usedThisPeriod, 15)
        XCTAssertEqual(l.topUps, 4)
    }

    func testThePlanDoesNotUseTheFreeFirstCheck() {
        let s = state(.free)
        let now = d(2026, 11, 9)
        let l = CheckLedger()
        XCTAssertTrue(l.balance(s, now: now, calendar: cal).firstFreeAvailable)
        XCTAssertFalse(l.canSpend(3, s, now: now, calendar: cal), "1 monthly check and the free first one are not 3")
        XCTAssertTrue(l.canSpend(0, s, now: now, calendar: cal))
    }

    func testRunningChecksAreCountedAgainstAPlan() {
        let s = state(.plus)
        let now = d(2026, 11, 9)
        var l = CheckLedger()
        l.roll(s, now: now, calendar: cal)
        l.usedThisPeriod = 12
        XCTAssertTrue(l.canSpend(3, s, now: now, calendar: cal))
        XCTAssertFalse(l.canSpend(3, s, now: now, inFlight: 1, calendar: cal))
    }

    func testTheMoneyLineUsesTheMiddleOfEachInput() throws {
        let id = UUID()
        let inputs = ReturnInputs(price: .init(low: 30, high: 50, basis: "clinic price", sourceID: id),
                                  reachable: .init(low: 20, high: 40, basis: "metro clinics", sourceID: id),
                                  conversion: .init(low: 0.1, high: 0.3, basis: "guess"))
        let m = try XCTUnwrap(PlanMoney(inputs))
        XCTAssertEqual(m.price, 40)
        XCTAssertEqual(m.customers, 30)
        XCTAssertEqual(m.sharePercent, "20%")
        XCTAssertEqual(m.monthly, 240, accuracy: 0.001)
        XCTAssertTrue(m.shareIsAssumption)
        XCTAssertFalse(m.priceIsAssumption)

        let noPrice = ReturnInputs(price: .init(low: 30, high: 50, basis: "wish"), reachable: inputs.reachable, conversion: inputs.conversion)
        XCTAssertNil(PlanMoney(noPrice), "no sourced price, no money line")
    }

    func testWhatChangedSinceThePlan() {
        let old = LaunchPlan.Basis(conversations: 1, proofStep: 1, checkedAt: d(2026, 11, 1))
        XCTAssertEqual(LaunchPlan.changes(from: old, to: old), [])
        let new = LaunchPlan.Basis(conversations: 3, proofStep: 2, checkedAt: d(2026, 11, 8))
        XCTAssertEqual(LaunchPlan.changes(from: old, to: new), ["2 more conversations", "proof moved up a step", "a newer panel take"])
    }

    func testThePrintedPageEscapesTextAndMarksBeliefs() {
        let p = plan()
        let html = LaunchPlanDocument.html(.init(title: "Clinic-issued ID tags", plan: p, potential: "Promising", proof: "Talked to 3",
                                                 nextStep: "ask one of them to pay", money: nil, moneyNote: "Too early to estimate",
                                                 sourceTitles: [p.proven[0].sourceID!: "Call with Dale"], dateText: "November 9, 2026"))
        XCTAssertTrue(html.contains("Tags for clinics &lt;fast&gt;"))
        XCTAssertFalse(html.contains("<fast>"))
        XCTAssertTrue(html.contains("<li class=\"solid\">3 directors said lost cards are weekly <span class=\"src\">(Call with Dale)</span>"))
        XCTAssertTrue(html.contains("<li class=\"hollow\">No clinic has paid yet</li>"))
        XCTAssertTrue(html.contains("Days 61–90"))
        XCTAssertTrue(html.contains("Too early to estimate"))
        XCTAssertTrue(html.contains("Next: ask one of them to pay"))
    }
}
