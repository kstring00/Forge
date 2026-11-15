import XCTest
@testable import ForgeCore

final class PlanSignalTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let name = "PlanSignalTests.\(UUID().uuidString)"
        let d = UserDefaults(suiteName: name)!
        d.removePersistentDomain(forName: name)
        return d
    }

    private func state(_ plan: Plan, trial: Bool = false) -> MembershipState {
        MembershipState(plan: plan, isTrial: trial, anchor: Date(timeIntervalSince1970: 1_800_000_000), productID: nil, renewsAt: nil, founding: false)
    }

    func testThePlanSentToTheProxyIsTheSavedOne() throws {
        let d = defaults()
        XCTAssertEqual(PlanSignal.current(defaults: d), "free", "nothing saved is free")
        d.set(try JSONEncoder().encode(state(.plus)), forKey: PlanSignal.stateKey)
        XCTAssertEqual(PlanSignal.current(defaults: d), "plus")
        d.set(try JSONEncoder().encode(state(.pro)), forKey: PlanSignal.stateKey)
        XCTAssertEqual(PlanSignal.current(defaults: d), "pro")
        d.set(try JSONEncoder().encode(state(.plus, trial: true)), forKey: PlanSignal.stateKey)
        XCTAssertEqual(PlanSignal.current(defaults: d), "plus", "a trial is on the plan it is trying")
        d.set(Data("not json".utf8), forKey: PlanSignal.stateKey)
        XCTAssertEqual(PlanSignal.current(defaults: d), "free", "unreadable is free")
    }

    func testTheSpendScreenReadsTheProxysAnswerAndSaysItPlainly() throws {
        let json = """
        {"day":"2026-11-15","timeZone":"America/Chicago","ceilingUSD":3,"freeTierStopsAtUSD":2.1,"state":"paidOnly",
         "today":{"from":"2026-11-15","to":"2026-11-15","days":1,"usd":2.25,"checks":12,"checkUSD":2.04,"averagePerCheckUSD":0.17},
         "week":{"from":"2026-11-09","to":"2026-11-15","days":7,"usd":9.5,"checks":51,"checkUSD":8.9,"averagePerCheckUSD":0.1745},
         "month":{"from":"2026-11-01","to":"2026-11-15","days":15,"usd":0,"checks":0,"checkUSD":0,"averagePerCheckUSD":null},
         "store":"redis"}
        """
        let s = try JSONDecoder().decode(OwnerSpend.self, from: Data(json.utf8))
        XCTAssertEqual(s.todayLine, "$2.25 of $3.00 today")
        XCTAssertEqual(s.share, 0.75)
        XCTAssertEqual(s.stateLine, "Past $2.10: free users can't start a check today. Paid plans carry on to $3.00.")
        XCTAssertEqual(OwnerSpend.checksLine(s.today), "12 checks · 17¢ each")
        XCTAssertEqual(OwnerSpend.checksLine(s.month), "No checks yet")
        XCTAssertEqual(OwnerSpend.money(0.004), "<$0.01")
        var resting = s
        resting.state = "resting"
        XCTAssertTrue(resting.stateLine.hasPrefix("The ceiling is reached."))
        var open = s
        open.state = "open"
        XCTAssertTrue(open.stateLine.hasPrefix("Everyone is being served."))
    }
}
