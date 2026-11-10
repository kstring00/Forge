import XCTest
@testable import ForgeCore

/// Decision 0043: the plan comes from Apple's current entitlement and renewal
/// info, and checks follow the billing period through every event. Numbers
/// are today's config (Free 1, Plus 15, Pro 50, trial 5, top-up 5).
final class SubscriptionLifecycleTests: XCTestCase {
    private let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    private func d(_ y: Int, _ m: Int, _ day: Int, _ h: Int = 12) -> Date { cal.date(from: DateComponents(year: y, month: m, day: day, hour: h))! }
    private func months(_ n: Int, after date: Date) -> Date { cal.date(byAdding: .month, value: n, to: date)! }
    private func short(_ date: Date) -> String {
        let c = cal.dateComponents([.month, .day], from: date)
        return "\(["", "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"][c.month!]) \(c.day!)"
    }

    /// What StoreKit would say for a subscription bought (or renewed) at `from`.
    private func sub(_ id: String, from: Date, to: Date? = nil, txn: String = UUID().uuidString, trial: Bool = false,
                     renewal: SubscriptionSnapshot.Renewal = .subscribed, entitled: Bool = true, autoRenew: Bool = true,
                     next: String? = nil, grace: Date? = nil, family: Bool = false) -> SubscriptionSnapshot {
        let end = to ?? (trial ? from.addingTimeInterval(7 * 86_400) : months(MembershipProduct.isYearly(id) ? 12 : 1, after: from))
        return SubscriptionSnapshot(productID: id, transactionID: txn, purchaseDate: from, expiresAt: end, isTrial: trial,
                                    isEntitled: entitled, renewal: renewal, willAutoRenew: autoRenew,
                                    autoRenewProductID: autoRenew ? (next ?? id) : nil, gracePeriodEndsAt: grace, familyShared: family)
    }

    /// The phone: applies what the App Store says, as `LocalEntitlements` does.
    private struct Phone {
        var ledger = CheckLedger(firstFreeUsed: true)
        var state = MembershipState.free
        let cal: Calendar
        mutating func apply(_ s: SubscriptionSnapshot?, at t: Date) { apply(MembershipState(entitlement: s), at: t) }
        mutating func apply(_ s: MembershipState, at t: Date) { state = s; ledger.roll(s, now: t, calendar: cal) }
        mutating func use(_ n: Int, at t: Date) { for _ in 0..<n { ledger.commit(state, now: t, calendar: cal) } }
        func balance(at t: Date) -> CheckBalance { ledger.balance(state, now: t, calendar: cal) }
    }
    private func phone() -> Phone { Phone(cal: cal) }

    // MARK: The bug

    /// The reported bug, at the ledger: cycles used to be pinned to the first
    /// purchase ever (Apple keeps `originalPurchaseDate` across upgrades), so a
    /// Pro → Plus downgrade landing at renewal fell inside Pro's cycle and
    /// Plus started with Pro's usage: 0 of 15 for the paid month.
    func testADowngradeAtRenewalStartsPlusWithFreshChecks() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 10, 3)), at: d(2026, 10, 3))
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 10, 20)), at: d(2026, 10, 20))   // upgrade: new billing date
        p.use(30, at: d(2026, 11, 10))
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 10, 20), next: MembershipProduct.plusMonthly), at: d(2026, 11, 12))
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 20)), at: d(2026, 11, 20))
        let b = p.balance(at: d(2026, 11, 21))
        XCTAssertEqual(b.monthlyLeft, 15)
        XCTAssertEqual(b.rolledOverLeft, 15, "Pro's 20 unused carry, capped at Plus's 15")
        XCTAssertEqual(short(b.resetsAt), "Dec 20")
    }

    // MARK: 1–15, the rules

    /// 1. New subscription: Free's unused check carries (up to Free's 1); Plus starts today.
    func testNewSubscription() {
        var p = phone()
        p.apply(.free, at: d(2026, 11, 2))
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        let b = p.balance(at: d(2026, 11, 9))
        XCTAssertEqual(b.monthlyLeft, 15)
        XCTAssertEqual(b.rolledOverLeft, 1)
        XCTAssertEqual(short(b.resetsAt), "Dec 9")
    }

    /// 2. Normal renewal: unused carry (capped at a month), carried-over spent first.
    /// Before the app hears of the renewal, nothing new is granted.
    func testNormalRenewal() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(5, at: d(2026, 11, 20))
        XCTAssertEqual(p.balance(at: d(2026, 12, 10)).monthlyLeft, 10, "Apple hasn't said it renewed: the old cycle carries on")
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 12, 9)), at: d(2026, 12, 10))
        let b = p.balance(at: d(2026, 12, 10))
        XCTAssertEqual(b.rolledOverLeft, 10)
        XCTAssertEqual(b.monthlyLeft, 15)
        p.use(1, at: d(2026, 12, 11))
        XCTAssertEqual(p.balance(at: d(2026, 12, 11)).rolledOverLeft, 9, "carried ones go first")
    }

    /// 3. Upgrade Plus → Pro: immediate; up to Plus's 15 carry; Pro's 50 start now; cycles follow the new billing date.
    /// Checks carried in from last month move with the upgrade (decision 0043).
    func testUpgradeIsImmediate() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(3, at: d(2026, 11, 10))
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 11, 20)), at: d(2026, 11, 20))
        let b = p.balance(at: d(2026, 11, 20))
        XCTAssertEqual(b.plan, .pro)
        XCTAssertEqual(b.rolledOverLeft, 12)
        XCTAssertEqual(b.monthlyLeft, 50)
        XCTAssertEqual(short(b.resetsAt), "Dec 20")
    }

    /// 3b. On an upgrade, carried-over and unused checks move over together, capped at the
    /// old plan's allowance (times the carry setting), and expire at the end of the new cycle.
    /// Carried checks are spent first, so with today's one-month cap any carried check left
    /// means none of this month's were used: the result is the same as carrying only unused.
    func testCarriedChecksMoveWithAnUpgrade() {
        let twoMonths = PlanRules(rollover: .init(enabled: true, capMonths: 2))
        var l = CheckLedger(firstFreeUsed: true)
        let oct = MembershipState(entitlement: sub(MembershipProduct.plusMonthly, from: d(2026, 10, 9)))
        l.roll(oct, now: d(2026, 10, 9), rules: twoMonths, calendar: cal)
        let nov = MembershipState(entitlement: sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)))
        l.roll(nov, now: d(2026, 11, 9), rules: twoMonths, calendar: cal)
        XCTAssertEqual(l.rolledOver, 15, "October's 15 unused")
        for _ in 0..<5 { l.commit(nov, now: d(2026, 11, 10), rules: twoMonths, calendar: cal) }   // 5 of the carried
        let pro = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 20)))
        let b = l.balance(pro, now: d(2026, 11, 20), rules: twoMonths, calendar: cal)
        XCTAssertEqual(b.rolledOverLeft, 10 + 15, "10 carried + 15 unused move; the cap is 2 × 15")
        XCTAssertEqual(short(b.resetsAt), "Dec 20", "and expire when Pro's first cycle ends")

        // The same at a renewal: carried checks expire, only unused ones carry.
        let renewal = MembershipState(entitlement: sub(MembershipProduct.plusMonthly, from: d(2026, 12, 9)))
        XCTAssertEqual(l.balance(renewal, now: d(2026, 12, 9), rules: twoMonths, calendar: cal).rolledOverLeft, 15)

        // Today's cap (one month): carried 10 + unused 15, capped at Plus's 15.
        var one = CheckLedger(firstFreeUsed: true)
        one.roll(oct, now: d(2026, 10, 9), calendar: cal)
        for _ in 0..<5 { one.commit(oct, now: d(2026, 10, 10), calendar: cal) }
        one.roll(nov, now: d(2026, 11, 9), calendar: cal)
        for _ in 0..<4 { one.commit(nov, now: d(2026, 11, 10), calendar: cal) }
        XCTAssertEqual(one.balance(pro, now: d(2026, 11, 20), calendar: cal).rolledOverLeft, 15)
        var moved = one
        moved.roll(pro, now: d(2026, 11, 20), calendar: cal)
        XCTAssertEqual(moved.events.last { $0.kind == .expire }?.checks, 6 + 15 - 15, "what didn't fit under the cap expires")
    }

    /// 3c. Chat Claude's case (Nov 10): a Plus user holding 5 carried-over and 6 unused checks
    /// upgrades to Pro and gets 11 carried plus Pro's allowance; under the old rule the 5 would
    /// have expired. The rule does give 11 for that balance. But spending can't produce that
    /// balance: carried checks are spent first, so while any are left, none of this month's 15
    /// are used. The second half walks every balance a Plus user can reach and shows the new
    /// rule and the old one agree at today's one-month cap.
    func testFiveCarriedPlusSixUnusedMoveAsEleven() {
        let oct = MembershipState(entitlement: sub(MembershipProduct.plusMonthly, from: d(2026, 10, 9)))
        let nov = MembershipState(entitlement: sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)))
        let pro = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 20)))
        /// A Plus ledger that carried 5 into November, then spent `n` checks there.
        func plus(spending n: Int) -> CheckLedger {
            var l = CheckLedger(firstFreeUsed: true)
            l.roll(oct, now: d(2026, 10, 9), calendar: cal)
            for _ in 0..<10 { l.commit(oct, now: d(2026, 10, 10), calendar: cal) }
            l.roll(nov, now: d(2026, 11, 9), calendar: cal)
            for _ in 0..<n { l.commit(nov, now: d(2026, 11, 10), calendar: cal) }
            return l
        }

        // The balance as asked, set by hand: 5 carried untouched, 9 of November's 15 used.
        var asked = plus(spending: 0)
        XCTAssertEqual(asked.rolledOver, 5)
        asked.usedThisPeriod = 9
        let b = asked.balance(pro, now: d(2026, 11, 20), calendar: cal)
        XCTAssertEqual(b.rolledOverLeft, 11, "5 carried + 6 unused move together")
        XCTAssertEqual(b.monthlyLeft, 50, "plus Pro's allowance")

        // Every balance spending can reach: 0 to 20 checks spent in November.
        for n in 0...20 {
            let l = plus(spending: n)
            let before = l.balance(nov, now: d(2026, 11, 19), calendar: cal)
            XCTAssertFalse(before.rolledOverLeft > 0 && before.monthlyLeft < 15, "carried checks go first (spent \(n))")
            let moved = l.balance(pro, now: d(2026, 11, 20), calendar: cal).rolledOverLeft
            XCTAssertEqual(moved, min(before.rolledOverLeft + before.monthlyLeft, 15), "carried + unused, capped at Plus's 15 (spent \(n))")
            XCTAssertEqual(moved, min(before.monthlyLeft, 15), "the same as carrying only the unused ones (spent \(n))")
        }
        // The closest reachable case: spend 14 (the 5 carried, then 9 of November's) → 6 unused → 6 move.
        XCTAssertEqual(plus(spending: 14).balance(pro, now: d(2026, 11, 20), calendar: cal).rolledOverLeft, 6)
    }

    /// 4. Downgrade Pro → Plus: booked for renewal; Pro and its checks stay until then.
    func testDowngradeWaitsForRenewal() {
        var p = phone()
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(10, at: d(2026, 11, 10))
        let before = p.balance(at: d(2026, 11, 15))
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 11, 9), next: MembershipProduct.plusMonthly), at: d(2026, 11, 15))
        XCTAssertEqual(p.state.plan, .pro)
        XCTAssertEqual(p.state.nextPlan, .plus)
        XCTAssertEqual(p.balance(at: d(2026, 11, 15)), before, "nothing changes until renewal")
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 12, 9)), at: d(2026, 12, 9))
        let b = p.balance(at: d(2026, 12, 9))
        XCTAssertEqual(b.plan, .plus)
        XCTAssertEqual(b.rolledOverLeft, 15, "Pro's 40 unused, capped at Plus's 15")
        XCTAssertEqual(b.monthlyLeft, 15)
    }

    /// 5. Undoing a booked downgrade before renewal: nothing changes.
    func testUndoingADowngradeChangesNothing() {
        var p = phone()
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(4, at: d(2026, 11, 10))
        let before = p.balance(at: d(2026, 11, 12))
        let events = p.ledger.events.count
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 11, 9), next: MembershipProduct.plusMonthly), at: d(2026, 11, 11))
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 12))
        XCTAssertNil(p.state.nextProductID)
        XCTAssertEqual(p.balance(at: d(2026, 11, 12)), before)
        XCTAssertEqual(p.ledger.events.count, events, "no grant, carry or expiry")
    }

    /// 6. Monthly ↔ yearly on the same plan: at the switch date the anchor moves; rollover as at a renewal.
    func testMonthlyToYearlyMovesTheAnchorAtTheSwitch() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(6, at: d(2026, 11, 10))
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9), next: MembershipProduct.plusYearly), at: d(2026, 11, 20))
        XCTAssertEqual(p.balance(at: d(2026, 11, 20)).monthlyLeft, 9, "still monthly until Dec 9")
        p.apply(sub(MembershipProduct.plusYearly, from: d(2026, 12, 9)), at: d(2026, 12, 9))
        var b = p.balance(at: d(2026, 12, 9))
        XCTAssertEqual(b.rolledOverLeft, 9)
        XCTAssertEqual(b.monthlyLeft, 15)
        XCTAssertEqual(short(b.resetsAt), "Jan 9")
        b = p.balance(at: d(2027, 1, 9))
        XCTAssertEqual(b.monthlyLeft, 15, "a yearly plan gets a fresh allowance every month")
        XCTAssertEqual(b.rolledOverLeft, 15)
    }

    /// 7. Cancel: runs to the end of the paid period with its checks; at expiry 1 carries into Free.
    func testCancelRunsToTheEndThenFree() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(2, at: d(2026, 11, 10))
        let before = p.balance(at: d(2026, 11, 15))
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9), autoRenew: false), at: d(2026, 11, 15))
        XCTAssertTrue(p.state.isCancelled)
        XCTAssertEqual(p.balance(at: d(2026, 12, 1)).monthlyLeft, before.monthlyLeft, "checks stay usable until it ends")
        p.apply(nil, at: d(2026, 12, 9))
        let b = p.balance(at: d(2026, 12, 9))
        XCTAssertEqual(b.plan, .free)
        XCTAssertEqual(b.rolledOverLeft, 1)
        XCTAssertEqual(b.monthlyLeft, 1)
    }

    /// 8. Resubscribing before expiry: as if never cancelled.
    func testResubscribingBeforeExpiry() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(2, at: d(2026, 11, 10))
        let before = p.balance(at: d(2026, 11, 20))
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9), autoRenew: false), at: d(2026, 11, 15))
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 20))
        XCTAssertFalse(p.state.isCancelled)
        XCTAssertEqual(p.balance(at: d(2026, 11, 20)), before)
    }

    /// 9. Resubscribing after dropping to Free: a fresh allowance; carry by the same rules (Free's cap is 1).
    func testResubscribingAfterFree() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 10, 9), autoRenew: false), at: d(2026, 10, 9))
        p.apply(nil, at: d(2026, 11, 9))
        p.use(1, at: d(2026, 11, 10))   // the carried one
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 20)), at: d(2026, 11, 20))
        let b = p.balance(at: d(2026, 11, 20))
        XCTAssertEqual(b.monthlyLeft, 15)
        XCTAssertEqual(b.rolledOverLeft, 1, "Free's own check went unused")
        XCTAssertEqual(short(b.resetsAt), "Dec 20")
    }

    /// 10. Billing trouble: the plan and its checks stay through Apple's grace period;
    /// past it, it's an expiry; when payment goes through, a new cycle.
    func testGracePeriodThenLapseThenRecovery() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(5, at: d(2026, 11, 10))
        let grace = sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9), renewal: .inGracePeriod, grace: d(2026, 12, 25))
        p.apply(grace, at: d(2026, 12, 10))
        XCTAssertEqual(p.state.plan, .plus)
        XCTAssertEqual(p.state.billing, .gracePeriod(until: d(2026, 12, 25)))
        XCTAssertEqual(p.balance(at: d(2026, 12, 15)).monthlyLeft, 10, "same checks; no new month until Apple is paid")
        XCTAssertTrue(MembershipState(entitlement: grace).statusLine(date: short).contains("Update your payment details"))

        let lapsed = sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9), renewal: .inBillingRetry, entitled: false)
        p.apply(lapsed, at: d(2026, 12, 25))
        XCTAssertEqual(p.state.plan, .free)
        XCTAssertEqual(p.state.billing, .retrying(productID: MembershipProduct.plusMonthly))
        XCTAssertEqual(p.balance(at: d(2026, 12, 25)).rolledOverLeft, 1, "treated as an expiry")

        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 12, 28)), at: d(2026, 12, 28))
        let b = p.balance(at: d(2026, 12, 28))
        XCTAssertEqual(b.plan, .plus)
        XCTAssertEqual(b.monthlyLeft, 15)
        XCTAssertEqual(short(b.resetsAt), "Jan 28")
    }

    /// 11. Refund or revocation: an expiry at that moment. Nothing goes negative,
    /// even when a check that was running finishes after.
    func testRefundIsAnExpiryAndNothingGoesNegative() {
        var p = phone()
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.use(49, at: d(2026, 11, 10))
        p.apply(nil, at: d(2026, 11, 12))   // revoked: gone from current entitlements
        p.use(3, at: d(2026, 11, 12))
        let b = p.balance(at: d(2026, 11, 12))
        XCTAssertEqual(b.plan, .free)
        XCTAssertEqual(b.monthlyLeft, 0)
        XCTAssertEqual(b.rolledOverLeft, 0)
        XCTAssertGreaterThanOrEqual(b.total, 0)
        XCTAssertFalse(p.ledger.canStart(p.state, now: d(2026, 11, 12), calendar: cal))
        XCTAssertEqual(MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9), renewal: .revoked, entitled: false)), .free)
    }

    /// 12. Free trial: 5 checks that never carry. Trial → paid starts the normal allowance; trial cancelled → Free.
    func testTrial() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusYearly, from: d(2026, 11, 9), trial: true), at: d(2026, 11, 9))
        XCTAssertEqual(p.balance(at: d(2026, 11, 9)).monthlyAllowance, 5)
        p.use(2, at: d(2026, 11, 10))
        var paid = p
        paid.apply(sub(MembershipProduct.plusYearly, from: d(2026, 11, 16)), at: d(2026, 11, 16))
        var b = paid.balance(at: d(2026, 11, 16))
        XCTAssertEqual(b.monthlyLeft, 15)
        XCTAssertEqual(b.rolledOverLeft, 0, "trial checks never carry")
        XCTAssertEqual(short(b.resetsAt), "Dec 16")

        var cancelled = p
        cancelled.apply(sub(MembershipProduct.plusYearly, from: d(2026, 11, 9), trial: true, autoRenew: false), at: d(2026, 11, 12))
        cancelled.apply(nil, at: d(2026, 11, 16))
        b = cancelled.balance(at: d(2026, 11, 16))
        XCTAssertEqual(b.plan, .free)
        XCTAssertEqual(b.rolledOverLeft, 0)
    }

    /// 13. Founding member: Plus yearly bought with the founding offer code ($39.99 the
    /// first year). It is Plus yearly in every way; the renewal after it is a regular year.
    func testFoundingIsPlusYearlyWithAnOfferCode() {
        var code = sub(MembershipProduct.plusYearly, from: d(2026, 11, 9))
        code.offerCodeID = "Founding"
        let f = MembershipState(entitlement: code)
        let y = MembershipState(entitlement: sub(MembershipProduct.plusYearly, from: d(2026, 11, 9)))
        XCTAssertTrue(f.founding)
        XCTAssertFalse(y.founding)
        XCTAssertEqual(f.plan, y.plan)
        XCTAssertEqual(f.productID, y.productID)
        XCTAssertEqual(f.monthlyAllowance, y.monthlyAllowance)
        for m in 0..<14 {
            let t = d(2026, 11, 9).addingTimeInterval(Double(m) * 30 * 86_400)
            XCTAssertEqual(CheckPeriod.cycle(containing: t, for: f, calendar: cal).start, CheckPeriod.cycle(containing: t, for: y, calendar: cal).start)
        }
        XCTAssertFalse(MembershipState(entitlement: sub(MembershipProduct.plusYearly, from: d(2027, 11, 9))).founding, "year two is regular")
        XCTAssertFalse(MembershipProduct.all.contains("hunch.plus.founding.yearly"), "no founding product")
        // Only the founding offer earns the label: another offer code doesn't, nor the same code on another product.
        var other = code
        other.offerCodeID = "SpringSale"
        XCTAssertFalse(MembershipState(entitlement: other).founding)
        var pro = sub(MembershipProduct.proYearly, from: d(2026, 11, 9))
        pro.offerCodeID = "Founding"
        XCTAssertFalse(MembershipState(entitlement: pro).founding)
        // The offer's name lives in config.
        XCTAssertTrue(MembershipState(entitlement: other, rules: PlanRules(foundingOfferID: "SpringSale")).founding)
        XCTAssertEqual(PlanRules().foundingOfferID, "Founding")
    }

    /// 14. Top-ups never expire and plan changes never touch them; a refund removes only that purchase's unused checks.
    func testTopUps() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)), at: d(2026, 11, 9))
        p.ledger.creditTopUp(transactionID: "A")
        p.ledger.creditTopUp(transactionID: "B")
        XCTAssertFalse(p.ledger.creditTopUp(transactionID: "A"), "never granted twice")
        p.use(15 + 3, at: d(2026, 11, 20))                     // this month's, then 3 from A (oldest first)
        XCTAssertEqual(p.ledger.topUpLots.map(\.remaining), [2, 5])
        p.apply(sub(MembershipProduct.proMonthly, from: d(2026, 11, 25)), at: d(2026, 11, 25))
        p.apply(nil, at: d(2026, 12, 25))
        XCTAssertEqual(p.balance(at: d(2027, 6, 1)).topUps, 7, "untouched by upgrade, expiry and months passing")
        XCTAssertEqual(p.ledger.refundTopUp(transactionID: "A"), 2, "only A's unused checks")
        XCTAssertEqual(p.ledger.refundTopUp(transactionID: "A"), 0, "once")
        XCTAssertEqual(p.ledger.topUps, 5)
        XCTAssertEqual(p.ledger.refundTopUp(transactionID: "never-bought"), 0)
    }

    /// 15. Family Sharing (off for every Hunch product today): a shared plan behaves as the
    /// person's own; their own higher plan wins over a shared one.
    func testFamilySharedPlans() {
        let shared = sub(MembershipProduct.plusYearly, from: d(2026, 11, 1), family: true)
        let own = sub(MembershipProduct.proMonthly, from: d(2026, 11, 5))
        XCTAssertEqual(MembershipState(entitlement: shared).plan, .plus)
        XCTAssertTrue(MembershipState(entitlement: shared).familyShared)
        XCTAssertEqual(SubscriptionSnapshot.deciding([shared, own])?.productID, MembershipProduct.proMonthly)
        let expiredPro = sub(MembershipProduct.proMonthly, from: d(2026, 9, 5), renewal: .expired, entitled: false)
        XCTAssertEqual(SubscriptionSnapshot.deciding([expiredPro, shared])?.productID, MembershipProduct.plusYearly, "entitled first")
    }

    // MARK: Yearly plans get monthly checks

    func testYearlyCyclesFollowThePurchaseDay() {
        let ninth = MembershipState(entitlement: sub(MembershipProduct.proYearly, from: d(2026, 11, 9)))
        XCTAssertEqual(short(CheckPeriod.cycle(containing: d(2027, 3, 20), for: ninth, calendar: cal).start), "Mar 9")
        XCTAssertEqual(short(CheckPeriod.cycle(containing: d(2027, 3, 20), for: ninth, calendar: cal).end), "Apr 9")

        let last = MembershipState(entitlement: sub(MembershipProduct.plusYearly, from: d(2027, 1, 31)))
        let starts = (0..<12).map { m in short(CheckPeriod.cycle(containing: months(m, after: d(2027, 1, 31)).addingTimeInterval(3600), for: last, calendar: cal).start) }
        XCTAssertEqual(starts, ["Jan 31", "Feb 28", "Mar 31", "Apr 30", "May 31", "Jun 30", "Jul 31", "Aug 31", "Sep 30", "Oct 31", "Nov 30", "Dec 31"])
        XCTAssertEqual(short(CheckPeriod.cycle(containing: d(2027, 12, 31, 13), for: last, calendar: cal).end), "Jan 31", "the last cycle ends at renewal")
    }

    /// The StoreKit test clock shortens a year to minutes; the year is still split into twelve.
    func testAcceleratedYearIsSplitIntoTwelve() {
        let t0 = d(2026, 11, 9)
        let s = MembershipState(entitlement: sub(MembershipProduct.plusYearly, from: t0, to: t0.addingTimeInterval(360)))
        var p = phone()
        p.apply(s, at: t0)
        p.use(15, at: t0.addingTimeInterval(10))
        XCTAssertEqual(p.balance(at: t0.addingTimeInterval(20)).monthlyLeft, 0)
        XCTAssertEqual(p.balance(at: t0.addingTimeInterval(31)).monthlyLeft, 15, "a new month every 30 seconds")
        let monthly = MembershipState(entitlement: sub(MembershipProduct.plusMonthly, from: t0, to: t0.addingTimeInterval(30)))
        XCTAssertEqual(CheckPeriod.cycle(containing: t0.addingTimeInterval(20), for: monthly, calendar: cal).end, t0.addingTimeInterval(30))
    }

    // MARK: The plan picker

    func testPlanOptions() {
        let pro = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9)))
        XCTAssertEqual(PlanOption.for(MembershipProduct.proMonthly, in: pro), .current)
        XCTAssertEqual(PlanOption.for(MembershipProduct.plusMonthly, in: pro), .switchesOn(d(2026, 12, 9)))
        XCTAssertEqual(PlanOption.for(MembershipProduct.proYearly, in: pro), .switchesOn(d(2026, 12, 9)), "same plan, other length: at renewal")

        let plus = MembershipState(entitlement: sub(MembershipProduct.plusYearly, from: d(2026, 11, 9)))
        XCTAssertEqual(PlanOption.for(MembershipProduct.proMonthly, in: plus), .upgradeNow)
        XCTAssertEqual(PlanOption.for(MembershipProduct.plusMonthly, in: plus), .switchesOn(d(2027, 11, 9)), "the only same-level switch is another length: at renewal")
        XCTAssertEqual(PlanOption.for(MembershipProduct.plusMonthly, in: .free), .subscribe)

        let booked = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9), next: MembershipProduct.plusMonthly))
        XCTAssertEqual(PlanOption.for(MembershipProduct.plusMonthly, in: booked), .booked(d(2026, 12, 9)))
        XCTAssertEqual(PlanOption.for(MembershipProduct.proMonthly, in: booked), .currentSwitching(to: MembershipProduct.plusMonthly, on: d(2026, 12, 9)))

        let cancelled = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9), autoRenew: false))
        XCTAssertEqual(PlanOption.for(MembershipProduct.proMonthly, in: cancelled), .currentEnding(d(2026, 12, 9)))
        XCTAssertEqual(PlanOption.switchesOn(d(2026, 12, 9)).badge(date: short), "Switches on Dec 9")
        XCTAssertEqual(PlanOption.upgradeNow.badge(date: short), "Upgrade now")
        XCTAssertEqual(PlanOption.current.badge(date: short), "Current")
    }

    func testWhatPeopleAreToldBeforeConfirming() {
        let pro = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9)))
        XCTAssertEqual(PlanOption.for(MembershipProduct.plusMonthly, in: pro).confirmation(productID: MembershipProduct.plusMonthly, in: pro, price: "$9.99 a month", date: short),
                       "You keep Pro · monthly until Dec 9. Plus · monthly starts then at $9.99 a month. Nothing is charged today.")
        let plus = MembershipState(entitlement: sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9)))
        let up = PlanOption.for(MembershipProduct.proMonthly, in: plus).confirmation(productID: MembershipProduct.proMonthly, in: plus, price: "$24.99 a month", date: short)!
        XCTAssertTrue(up.hasPrefix("Pro · monthly starts now. Apple charges $24.99 a month today and gives back the unused part of Plus · monthly."))
        XCTAssertNil(PlanOption.current.confirmation(productID: MembershipProduct.proMonthly, in: pro, price: "", date: short))
    }

    func testStatusLines() {
        let booked = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9), next: MembershipProduct.plusMonthly))
        XCTAssertEqual(booked.statusLine(date: short), "You're on Pro until Dec 9, then Plus · monthly.")
        let cancelled = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9), autoRenew: false))
        XCTAssertEqual(cancelled.statusLine(date: short), "Pro ends Dec 9. You'll move to Free.")
        XCTAssertNil(cancelled.nextProductID, "a cancelled plan books no switch")
        let normal = MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9)))
        XCTAssertEqual(normal.statusLine(date: short), "Pro renews Dec 9.")
        let retry = MembershipState(entitlement: sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9), renewal: .inBillingRetry, entitled: false))
        XCTAssertEqual(retry.statusLine(date: short), "Your last payment didn't go through, so Plus is paused. Update your payment details to get it back.")
    }

    // MARK: Events and recovery

    func testEveryChangeIsRecordedWithItsTransaction() {
        var p = phone()
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9), txn: "T1"), at: d(2026, 11, 9))
        p.use(5, at: d(2026, 11, 10))
        p.ledger.creditTopUp(transactionID: "TOP", now: d(2026, 11, 11))
        p.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 12, 9), txn: "T2"), at: d(2026, 12, 9))
        let kinds = p.ledger.events.map(\.kind)
        XCTAssertEqual(kinds.filter { $0 == .spend }.count, 5)
        XCTAssertTrue(kinds.contains(.topUp))
        let carry = p.ledger.events.first { $0.kind == .carry }
        XCTAssertEqual(carry?.checks, 10)
        XCTAssertEqual(carry?.transactionID, "T2")
        XCTAssertEqual(p.ledger.events.last { $0.kind == .grant }?.transactionID, "T2")
    }

    func testMergingTwoCopiesNeverAddsChecks() {
        var phoneA = phone()
        phoneA.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 11, 9), txn: "T1"), at: d(2026, 11, 9))
        phoneA.ledger.creditTopUp(transactionID: "TOP")
        var phoneB = phoneA
        phoneA.use(3, at: d(2026, 11, 10))
        phoneB.use(15 + 2, at: d(2026, 11, 11))
        _ = phoneB.ledger.refundTopUp(transactionID: "TOP")
        let m = phoneA.ledger.merged(with: phoneB.ledger)
        XCTAssertEqual(m.usedThisPeriod, 15)
        XCTAssertEqual(m.topUps, 0, "the refund on either copy stands")
        XCTAssertEqual(m.merged(with: m), m, "merging is stable")
        XCTAssertTrue(phoneA.ledger.merged(with: CheckLedger()).firstFreeUsed)

        // A copy from an older cycle doesn't roll the newer one back.
        var later = phoneA
        later.apply(sub(MembershipProduct.plusMonthly, from: d(2026, 12, 9), txn: "T2"), at: d(2026, 12, 9))
        XCTAssertEqual(later.ledger.merged(with: phoneB.ledger).periodStart, d(2026, 12, 9))
        XCTAssertEqual(phoneB.ledger.merged(with: later.ledger).periodStart, d(2026, 12, 9))
    }

    func testRestoreMarksHistoricTopUpsWithoutGivingThemAgain() {
        var l = CheckLedger(firstFreeUsed: true)
        XCTAssertEqual(l.recordKnownTopUps(["A", "B"]), 2)
        XCTAssertEqual(l.topUps, 0)
        XCTAssertFalse(l.creditTopUp(transactionID: "A"), "a replayed transaction isn't credited")
    }

    func testOlderSavedDataStillLoads() throws {
        let ledger = try JSONDecoder().decode(CheckLedger.self, from: Data(#"{"periodStart":0,"usedThisPeriod":4,"topUps":3,"firstFreeUsed":true,"creditedTransactions":["t"]}"#.utf8))
        XCTAssertEqual(ledger.topUps, 3)
        XCTAssertEqual(ledger.topUpLots.count, 1)
        let state = try JSONDecoder().decode(MembershipState.self, from: Data(#"{"plan":"plus","isTrial":false,"founding":false,"anchor":0}"#.utf8))
        XCTAssertEqual(state.plan, .plus)
        XCTAssertTrue(state.willAutoRenew)
        XCTAssertEqual(state.billing, .ok)
        let round = try JSONDecoder().decode(MembershipState.self, from: JSONEncoder().encode(MembershipState(entitlement: sub(MembershipProduct.proMonthly, from: d(2026, 11, 9), renewal: .inGracePeriod, grace: d(2026, 12, 1)))))
        XCTAssertEqual(round.billing, .gracePeriod(until: d(2026, 12, 1)))
    }
}
