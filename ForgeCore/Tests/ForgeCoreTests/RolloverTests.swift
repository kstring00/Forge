import XCTest
@testable import ForgeCore

/// Decision 0042, F: unused monthly checks carry into the next cycle, up to
/// one month's allowance, expire at the end of that cycle, and are spent first.
final class RolloverTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))! }
    private func plan(_ p: Plan, anchor: Date?, trial: Bool = false) -> MembershipState {
        MembershipState(plan: p, isTrial: trial, anchor: anchor, productID: nil, renewsAt: nil, founding: false)
    }
    private let anchor = Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"), year: 2026, month: 10, day: 3, hour: 12))!

    /// A Plus ledger that used `n` checks in the Oct 3 – Nov 3 cycle.
    private func plusLedger(used n: Int) -> CheckLedger {
        var l = CheckLedger(firstFreeUsed: true)
        let s = plan(.plus, anchor: anchor)
        l.roll(s, now: d(2026, 10, 4), calendar: cal)   // the app rolls at launch and on every plan change
        for _ in 0..<n { l.commit(s, now: d(2026, 10, 10), calendar: cal) }
        return l
    }

    func testUnusedChecksCarryOverAndAreSpentFirst() {
        let s = plan(.plus, anchor: anchor)
        var l = plusLedger(used: 11)
        _ = l.creditTopUp(transactionID: "t")
        let b = l.balance(s, now: d(2026, 11, 5), calendar: cal)
        XCTAssertEqual(b.rolledOverLeft, 4, "15 − 11 carry")
        XCTAssertEqual(b.monthlyLeft, 15)
        XCTAssertEqual(b.total, 4 + 15 + 5)
        XCTAssertEqual(b.line(resets: "Dec 3"), "15 of 15 checks left · +4 carried over · +5 extra · resets Dec 3")
        XCTAssertEqual(l.commit(s, now: d(2026, 11, 5), calendar: cal), .rolledOver, "carried checks go first: they expire soonest")
        for _ in 0..<3 { l.commit(s, now: d(2026, 11, 6), calendar: cal) }
        XCTAssertEqual(l.commit(s, now: d(2026, 11, 7), calendar: cal), .monthly)
        XCTAssertEqual(l.topUps, 5, "bought checks wait until last")
    }

    func testCarriedChecksExpireAtTheEndOfTheCycleTheyCarriedInto() {
        let s = plan(.plus, anchor: anchor)
        var l = plusLedger(used: 5)
        XCTAssertEqual(l.balance(s, now: d(2026, 11, 5), calendar: cal).rolledOverLeft, 10)
        // Use 2 of the 10 carried and none of November's 15.
        l.commit(s, now: d(2026, 11, 5), calendar: cal)
        l.commit(s, now: d(2026, 11, 5), calendar: cal)
        let dec = l.balance(s, now: d(2026, 12, 5), calendar: cal)
        XCTAssertEqual(dec.rolledOverLeft, 15, "November's 15 unused carry; October's leftover 8 expired, never carried twice")
    }

    func testTheCarryIsCappedAtOneMonth() {
        let s = plan(.plus, anchor: anchor)
        var l = CheckLedger(firstFreeUsed: true)
        l.commit(s, now: d(2026, 10, 10), calendar: cal)
        // Not opened for two months: November went unused too; still one month's worth.
        let b = l.balance(s, now: d(2026, 12, 20), calendar: cal)
        XCTAssertEqual(b.rolledOverLeft, 15)
        XCTAssertEqual(b.monthlyLeft, 15)
        let capped = PlanRules(rollover: .init(enabled: true, capMonths: 0))
        XCTAssertEqual(plusLedger(used: 0).balance(s, now: d(2026, 11, 5), rules: capped, calendar: cal).rolledOverLeft, 0, "the cap is a setting")
        let off = PlanRules(rollover: .init(enabled: false))
        XCTAssertEqual(plusLedger(used: 0).balance(s, now: d(2026, 11, 5), rules: off, calendar: cal).rolledOverLeft, 0)
    }

    func testPlanChanges() {
        // Upgrade to Pro in a new cycle: Plus's unused carry, up to Plus's allowance.
        var up = plusLedger(used: 3)
        let pro = plan(.pro, anchor: d(2026, 10, 20))
        let b1 = up.balance(pro, now: d(2026, 10, 21), calendar: cal)
        XCTAssertEqual(b1.rolledOverLeft, 12)
        XCTAssertEqual(b1.monthlyLeft, 60)
        up.roll(pro, now: d(2026, 10, 21), calendar: cal)

        // Downgrade Pro → Plus at renewal: at most Plus's 15 carry.
        var pl = CheckLedger(firstFreeUsed: true)
        pl.commit(pro, now: d(2026, 10, 25), calendar: cal)
        XCTAssertEqual(pl.balance(plan(.plus, anchor: d(2026, 11, 20)), now: d(2026, 11, 21), calendar: cal).rolledOverLeft, 15)

        // Cancel → Free: at most Free's 1 carries; bought checks stay.
        var c = plusLedger(used: 0)
        _ = c.creditTopUp(transactionID: "t")
        let free = c.balance(.free, now: d(2026, 11, 5), calendar: cal)
        XCTAssertEqual(free.rolledOverLeft, 1)
        XCTAssertEqual(free.monthlyLeft, 1)
        XCTAssertEqual(free.topUps, 5)

        // Trial checks never carry.
        var t = CheckLedger(firstFreeUsed: true)
        t.commit(plan(.plus, anchor: anchor, trial: true), now: d(2026, 10, 5), calendar: cal)
        XCTAssertEqual(t.balance(plan(.plus, anchor: anchor), now: d(2026, 11, 5), calendar: cal).rolledOverLeft, 0)
    }

    func testALedgerSavedBeforeRolloverStillLoads() throws {
        let old = #"{"periodStart":0,"usedThisPeriod":4,"topUps":2,"firstFreeUsed":true,"creditedTransactions":["t"]}"#
        let l = try JSONDecoder().decode(CheckLedger.self, from: Data(old.utf8))
        XCTAssertEqual(l.usedThisPeriod, 4)
        XCTAssertEqual(l.topUps, 2)
        XCTAssertEqual(l.rolledOver, 0)
        XCTAssertNil(l.allowanceThisPeriod)
    }
}

extension RolloverTests {
    func testThePillSaysWhatExpiresSoonest() {
        let s = MembershipState(plan: .plus, isTrial: false, anchor: Calendar(identifier: .gregorian).date(from: DateComponents(timeZone: TimeZone(identifier: "UTC"), year: 2026, month: 10, day: 3, hour: 12))!, productID: nil, renewsAt: nil, founding: false)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        var l = CheckLedger(firstFreeUsed: true)
        l.roll(s, now: cal.date(from: DateComponents(year: 2026, month: 10, day: 4))!, calendar: cal)
        for _ in 0..<11 { l.commit(s, now: cal.date(from: DateComponents(year: 2026, month: 10, day: 10))!, calendar: cal) }
        let b = l.balance(s, now: cal.date(from: DateComponents(year: 2026, month: 11, day: 5))!, calendar: cal)
        XCTAssertEqual(b.pillLine(resets: "Dec 3"), "19 checks left · 4 carried over expire Dec 3")
        XCTAssertEqual(CheckLedger(firstFreeUsed: true).balance(.free, now: Date(), calendar: cal).pillLine(resets: "Dec 1"), "1 of 1 check left · resets Dec 1")
    }
}
