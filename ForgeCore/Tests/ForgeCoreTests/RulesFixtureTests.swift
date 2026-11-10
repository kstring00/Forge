import XCTest
@testable import ForgeCore

/// Decision 0042, G: the numbers the proxy serves (proxy/config/hunch.ts, kept
/// equal to proxy/test/fixtures/rules.json by a proxy test) decode into
/// PlanRules and equal the defaults the app ships with.
final class RulesFixtureTests: XCTestCase {
    func testTheServersRulesAreTheShippedDefaults() throws {
        let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let data = try Data(contentsOf: repo.appending(path: "proxy/test/fixtures/rules.json"))
        let served = try JSONDecoder().decode(PlanRules.self, from: data)
        XCTAssertEqual(served, PlanRules(), "change PlanRules' defaults and the proxy config together")
        XCTAssertEqual(served.monthlyChecks(for: .plus), 15)
    }

    func testPlansReadTheirNumbersFromTheRules() {
        let saved = PlanRules.current
        defer { PlanRules.current = saved }
        PlanRules.current = PlanRules(monthlyChecks: ["free": 2, "plus": 20, "pro": 80], trialChecks: 7, topUpChecks: 6)
        XCTAssertEqual(Plan.allCases.map(\.monthlyChecks), [2, 20, 80])
        XCTAssertEqual(MembershipState.trialChecks, 7)
        XCTAssertEqual(MembershipProduct.topUpChecks, 6)
        XCTAssertEqual(PlanRules(monthlyChecks: [:]).monthlyChecks(for: .pro), 50, "a plan the server leaves out keeps its default")
    }
}
