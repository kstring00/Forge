import XCTest
@testable import ForgeCore

final class RealityCheckPolicyTests: XCTestCase {
    func testOnlyBusinessAndUnsetLensesGetTheCheck() {
        XCTAssertTrue(RealityCheckPolicy.isOffered(for: nil))
        XCTAssertTrue(RealityCheckPolicy.isOffered(for: .business))
        XCTAssertFalse(RealityCheckPolicy.isOffered(for: .growth))
        XCTAssertFalse(RealityCheckPolicy.isOffered(for: .creative))
    }

    func testCents() {
        XCTAssertEqual(RealityCheckCost.cents(0.14), "14¢")
        XCTAssertEqual(RealityCheckCost.cents(0.004), "<1¢")
        XCTAssertEqual(RealityCheckCost.cents(0.996), "$1.00")
        XCTAssertEqual(RealityCheckCost.cents(1.2), "$1.20")
        XCTAssertEqual(RealityCheckCost.range(0.10...0.25), "10–25¢")
        XCTAssertEqual(RealityCheckCost.range(0.15...0.60), "15–60¢")
        XCTAssertEqual(RealityCheckCost.range(0.5...1.2), "$0.50–$1.20")
    }

    func testAverageUsesRecentRealRunsOnly() {
        XCTAssertNil(RealityCheckCost.average(ofRecent: []))
        XCTAssertNil(RealityCheckCost.average(ofRecent: [0, 0]))
        XCTAssertEqual(RealityCheckCost.average(ofRecent: [0.1, 0, 0.2])!, 0.15, accuracy: 1e-9)
        // Only the newest five count, so an old, pricier routing fades out.
        XCTAssertEqual(RealityCheckCost.average(ofRecent: [0.1, 0.1, 0.1, 0.1, 0.1, 0.9, 0.9])!, 0.1, accuracy: 1e-9)
    }

    func testDisclosureCopy() {
        XCTAssertEqual(RealityCheckCost.disclosure(estimate: 0.10...0.25, average: nil),
                       "Runs on AI · about 10–25¢ · your idea text is sent to the model.")
        XCTAssertEqual(RealityCheckCost.disclosure(estimate: 0.10...0.25, average: 0.137),
                       "Runs on AI · about 14¢ · your idea text is sent to the model.")
    }

    func testMonthCountsAndSpend() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let now = cal.date(from: DateComponents(year: 2026, month: 11, day: 7))!
        let earlier = cal.date(from: DateComponents(year: 2026, month: 11, day: 1))!
        let lastMonth = cal.date(from: DateComponents(year: 2026, month: 10, day: 31))!
        let m = RealityCheckCost.month([(now, 0.12), (earlier, nil), (lastMonth, 0.5)], now: now, calendar: cal)
        XCTAssertEqual(m.count, 2)
        XCTAssertEqual(m.spentUSD, 0.12, accuracy: 1e-9)
    }
}
