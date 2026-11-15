import XCTest
@testable import ForgeCore

/// Decision 0042: what costs a check, and the quiet daily limits on what doesn't.
final class PlanRulesTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private func d(_ day: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: 2026, month: 11, day: day, hour: h))! }

    func testOnlyResearchCostsACheck() {
        let r = PlanRules()
        XCTAssertEqual(r.costs.check, 1)
        XCTAssertEqual(r.costs.freshRecheck, 1)
        XCTAssertEqual(FollowUp.allCases.map { $0.cost(r) }, [0, 0, 0, 0])
        XCTAssertEqual(PlanRules.label(checks: 1), "1 check")
        XCTAssertEqual(PlanRules.label(checks: 0), "Included")
    }

    func testFairUseCountsPerIdeaPerDayAndPlansShareOneCount() {
        let a = UUID(), b = UUID()
        var l = FairUseLedger()
        for _ in 0..<2 { l.record(.launchPlan, ideaID: a, now: d(9), calendar: cal) }
        XCTAssertTrue(l.canUse(.launchPlanUpdate, ideaID: a, now: d(9), calendar: cal))
        l.record(.launchPlanUpdate, ideaID: a, now: d(9), calendar: cal)
        XCTAssertFalse(l.canUse(.launchPlan, ideaID: a, now: d(9), calendar: cal), "3 a day, new and updates together")
        XCTAssertTrue(l.canUse(.launchPlan, ideaID: b, now: d(9), calendar: cal), "per idea")
        XCTAssertTrue(l.canUse(.rescore, ideaID: a, now: d(9), calendar: cal), "per kind")
        XCTAssertTrue(l.canUse(.launchPlan, ideaID: a, now: d(10, 1), calendar: cal), "a new day starts from zero")
        l.record(.tank, ideaID: a, now: d(10), calendar: cal)
        XCTAssertEqual(l.used(.launchPlan, ideaID: a, now: d(10), calendar: cal), 0)
        XCTAssertEqual(l.counts.count, 1, "yesterday is dropped")
        XCTAssertFalse(FollowUp.launchPlan.limitMessage.lowercased().contains("upgrade"))
    }

    func testRulesDecodeWithDefaultsMissing() throws {
        let r = try JSONDecoder().decode(PlanRules.self, from: Data(#"{"costs":{"check":1,"freshRecheck":1,"launchPlan":0,"launchPlanUpdate":0,"rescore":0,"tank":0},"fairUse":{"launchPlansPerIdeaPerDay":5,"rescoresPerIdeaPerDay":10,"tankRunsPerIdeaPerDay":3}}"#.utf8))
        XCTAssertEqual(r.fairUse.launchPlansPerIdeaPerDay, 5)
    }
}
