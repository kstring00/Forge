import XCTest
@testable import ForgeCore

/// Decision 0042, H: the developer cost meter's arithmetic.
final class CostMeterTests: XCTestCase {
    func testAveragesByStageAndTheCacheHitRate() throws {
        var m = CostMeter()
        XCTAssertNil(m.summary)
        m.record(.init(at: .now, researchUSD: 0.06, scoringUSD: 0.004, briefUSD: 0.10, tokens: .init(fresh: 6000, cacheRead: 4000, cacheWrite: 0, output: 5000)))
        m.record(.init(at: .now, researchUSD: 0.04, scoringUSD: 0.002, briefUSD: 0.08, tokens: .init(fresh: 8000, cacheRead: 0, cacheWrite: 2000, output: 4000)))
        m.record(.init(at: .now, kind: "launchPlan", usd: 0.03, tokens: .init(fresh: 1000, cacheRead: 3000)))
        let s = try XCTUnwrap(m.summary)
        XCTAssertEqual(s.checks, 2)
        XCTAssertEqual(s.perCheckUSD, 0.143, accuracy: 0.0001)
        XCTAssertEqual(s.researchUSD, 0.05, accuracy: 0.0001)
        XCTAssertEqual(s.briefUSD, 0.09, accuracy: 0.0001)
        XCTAssertEqual(s.cacheHitRate, 7000.0 / 24000.0, accuracy: 0.0001)
        XCTAssertEqual(s.perFollowUpUSD ?? 0, 0.03, accuracy: 0.0001)
    }

    func testKeepsTheLatestFifty() {
        var m = CostMeter()
        for i in 0..<60 { m.record(.init(at: .now, kind: "\(i)", usd: 0, tokens: .init())) }
        XCTAssertEqual(m.followUps.count, 50)
        XCTAssertEqual(m.followUps.first?.kind, "10")
    }
}
