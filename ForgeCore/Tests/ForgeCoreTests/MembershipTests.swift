import XCTest
@testable import ForgeCore

/// Decision 0032: plans, periods and the check ledger.
final class MembershipTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))!
    }
    private func plus(anchor: Date, trial: Bool = false) -> MembershipState {
        MembershipState(plan: .plus, isTrial: trial, anchor: anchor, productID: MembershipProduct.plusYearly, renewsAt: nil, founding: false)
    }

    func testPlansAndProducts() {
        XCTAssertEqual(Plan.allCases.map(\.monthlyChecks), [1, 15, 50])
        XCTAssertTrue(Plan.free.includes(.whatIf), "Sparks are free on every plan")
        XCTAssertTrue(Plan.free.includes(.library), "the Library is your own work, on every plan")
        XCTAssertFalse(Plan.plus.includes(.priority))
        XCTAssertFalse(Plan.plus.includes(.deepResearch))
        XCTAssertTrue(Plan.pro.includes(.reports))
        XCTAssertNil(MembershipProduct.plan(for: "hunch.plus.founding.yearly"), "decision 0043: founders use an offer code on Plus yearly")
        XCTAssertEqual(MembershipProduct.plan(for: "hunch.pro.monthly"), .pro)
        XCTAssertNil(MembershipProduct.plan(for: "hunch.topup.5"))
        XCTAssertEqual(MembershipProduct.yearlySaving(monthly: 9.99, yearly: 59.99), 50)
        XCTAssertEqual(MembershipProduct.yearlySaving(monthly: 24.99, yearly: 179.99), 40)
        XCTAssertEqual(MembershipState.free.monthlyAllowance, 1)
        XCTAssertEqual(plus(anchor: d(2026, 11, 3), trial: true).monthlyAllowance, 5, "the trial is capped at 5")
    }

    func testFreeResetsOnTheFirst() {
        XCTAssertEqual(CheckPeriod.start(containing: d(2026, 11, 18), anchor: nil, calendar: cal), d(2026, 11, 1, 0))
        XCTAssertEqual(CheckPeriod.nextReset(after: d(2026, 11, 18), anchor: nil, calendar: cal), d(2026, 12, 1, 0))
    }

    func testPaidResetsOnTheMonthlyAnniversary() {
        let a = d(2026, 1, 31)
        XCTAssertEqual(CheckPeriod.start(containing: d(2026, 2, 10), anchor: a, calendar: cal), a)
        XCTAssertEqual(CheckPeriod.nextReset(after: d(2026, 2, 10), anchor: a, calendar: cal), d(2026, 2, 28), "Jan 31 → Feb 28")
        XCTAssertEqual(CheckPeriod.start(containing: d(2026, 3, 31, 13), anchor: a, calendar: cal), d(2026, 3, 31))
        XCTAssertEqual(CheckPeriod.nextReset(after: d(2026, 11, 8), anchor: d(2026, 11, 3), calendar: cal), d(2026, 12, 3))
    }

    func testFirstFreeThenMonthlyThenTopUps() {
        let state = plus(anchor: d(2026, 11, 3))
        var l = CheckLedger()
        let now = d(2026, 11, 8)
        XCTAssertEqual(l.commit(state, now: now, calendar: cal), .firstFree)
        for _ in 0..<15 { XCTAssertEqual(l.commit(state, now: now, calendar: cal), .monthly) }
        XCTAssertFalse(l.canStart(state, now: now, calendar: cal))
        XCTAssertTrue(l.creditTopUp(transactionID: "t1"))
        XCTAssertFalse(l.creditTopUp(transactionID: "t1"), "never twice")
        XCTAssertTrue(l.canStart(state, now: now, calendar: cal))
        XCTAssertEqual(l.balance(state, now: now, calendar: cal).line(resets: "Dec 3"), "0 of 15 checks left · +5 extra · resets Dec 3")
        XCTAssertEqual(l.commit(state, now: now, calendar: cal), .topUp)
        XCTAssertEqual(l.topUps, 4)

        // A new month: monthly checks come back, bought ones stay.
        let later = d(2026, 12, 4)
        let b = l.balance(state, now: later, calendar: cal)
        XCTAssertEqual(b.monthlyLeft, 15)
        XCTAssertEqual(b.topUps, 4)
    }

    func testInFlightChecksHoldTheirPlace() {
        var l = CheckLedger(firstFreeUsed: true)
        let now = d(2026, 11, 8)
        XCTAssertTrue(l.canStart(.free, now: now, inFlight: 0, calendar: cal))
        XCTAssertFalse(l.canStart(.free, now: now, inFlight: 1, calendar: cal), "one running uses the one Free check")
        l.commit(.free, now: now, calendar: cal)
        XCTAssertEqual(l.balance(.free, now: now, calendar: cal).line(resets: "Dec 1"), "0 of 1 check left · resets Dec 1")
    }

    func testAFreeCheckOnTheProxyIsNotCounted() {
        var l = CheckLedger(firstFreeUsed: true)
        XCTAssertEqual(l.commit(.free, now: d(2026, 11, 8), wasFreeOnProxy: true, calendar: cal), .firstFree)
        XCTAssertEqual(l.usedThisPeriod, 0)
        XCTAssertEqual(CheckLedger().balance(.free, now: d(2026, 11, 8), calendar: cal).line(resets: "Dec 1"), "Your first check is free")
    }
}
