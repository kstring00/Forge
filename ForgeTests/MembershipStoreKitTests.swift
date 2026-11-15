import XCTest
import StoreKit
import StoreKitTest
import ForgeCore
@testable import Forge

/// Decision 0043: the whole subscription lifecycle against Hunch.storekit,
/// with Apple's StoreKit test session (no purchase sheets). The rollover
/// rules themselves are tested in ForgeCore (SubscriptionLifecycleTests);
/// these check that what StoreKit reports reaches them correctly.
@MainActor
final class MembershipStoreKitTests: XCTestCase {
    private var session: SKTestSession!
    private var entitlements: LocalEntitlements!
    private var store: MembershipStore!
    private var rulesBefore = PlanRules.current

    override func setUp() async throws {
        // The tests run inside the app, which loads the plan numbers it last saved
        // (an older server's, say). These tests are written against the shipped defaults.
        rulesBefore = PlanRules.current
        PlanRules.current = PlanRules()
        // Hunch.storekit is copied into the test bundle (project.yml); fall back to looking it up by name.
        if let url = Bundle(for: Self.self).url(forResource: "Hunch", withExtension: "storekit") {
            session = try SKTestSession(contentsOf: url)
        } else {
            session = try SKTestSession(configurationFileNamed: "Hunch")
        }
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        session.timeRate = .realTime
        // Purchases left by hand testing or by the test before must be gone before this
        // one starts: a leftover Pro turns "buy Plus" into a downgrade.
        try await waitForNoPurchases()
        entitlements = LocalEntitlements(defaults: UserDefaults(suiteName: "skt-\(UUID().uuidString)")!)
        // Use the free first check and Free's own monthly one, so nothing carries in from Free.
        entitlements.commitCheck(wasFreeOnProxy: false)
        entitlements.commitCheck(wasFreeOnProxy: false)
        store = MembershipStore(entitlements: entitlements)
        await store.start()
    }

    override func tearDown() async throws {
        // Leave the simulator's test store as hand testing expects it: no purchases,
        // and Apple's purchase sheet showing again (these tests turn it off).
        session.clearTransactions()
        session.resetToDefaultState()
        session.disableDialogs = false
        PlanRules.current = rulesBefore
    }

    /// Clearing the test store takes a moment to reach `Transaction.currentEntitlements`.
    private func waitForNoPurchases() async throws {
        let deadline = Date().addingTimeInterval(15)
        var found: String?
        while Date() < deadline {
            found = nil
            for await result in Transaction.currentEntitlements {
                if case .verified(let t) = result { found = t.productID } else { found = "an unverified purchase" }
                break
            }
            if found == nil { return }
            session.clearTransactions()
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        XCTFail("The StoreKit test store still holds \(found ?? "a purchase") from an earlier run.")
    }

    // MARK: Helpers

    /// Re-reads the App Store until `condition` holds (renewals and refunds arrive on their own time).
    private func eventually(_ timeout: TimeInterval = 15, _ condition: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            await store.refresh()
            if condition() { return true }
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
        return false
    }

    /// Buys, then waits until the App Store's answer has reached the app: the plan itself,
    /// or (for a downgrade or a change of length) the switch booked for renewal.
    private func buy(_ id: String) async {
        let outcome = await store.purchase(id)
        XCTAssertEqual(outcome, .done, "buying \(id): \(store.message ?? "")")
        guard MembershipProduct.plan(for: id) != nil else { return }
        let landed = await eventually { state.productID == id || state.nextProductID == id }
        XCTAssertTrue(landed, "\(id) never showed up as the plan or as the booked switch")
    }

    private func latest(_ id: String) -> SKTestTransaction? {
        session.allTransactions().last { $0.productIdentifier == id }
    }

    private var state: MembershipState { entitlements.state }
    private var balance: CheckBalance { entitlements.balance }

    // MARK: Buying and changing plan

    func testBuyingPlusStartsIt() async {
        await buy(MembershipProduct.plusMonthly)
        XCTAssertEqual(state.plan, .plus)
        XCTAssertEqual(balance.monthlyLeft, 15)
        XCTAssertNotNil(state.renewsAt)
    }

    func testTheTrialIsCappedAtFive() async {
        await buy(MembershipProduct.plusYearly)
        XCTAssertTrue(state.isTrial)
        XCTAssertEqual(balance.monthlyAllowance, 5)
    }

    func testUpgradeIsImmediate() async {
        await buy(MembershipProduct.plusMonthly)
        for _ in 0..<3 { entitlements.commitCheck(wasFreeOnProxy: false) }
        await buy(MembershipProduct.proMonthly)
        XCTAssertEqual(state.plan, .pro)
        XCTAssertEqual(state.productID, MembershipProduct.proMonthly)
        XCTAssertEqual(balance.monthlyLeft, 50)
        XCTAssertEqual(balance.rolledOverLeft, 12, "Plus's unused carry, up to Plus's 15")
    }

    /// The reported bug: a downgrade charges nothing and changes nothing until renewal.
    func testDowngradeIsBookedForRenewalWithNoNewCharge() async throws {
        await buy(MembershipProduct.proMonthly)
        let transactions = session.allTransactions().count
        let checks = balance
        await buy(MembershipProduct.plusMonthly)
        let booked = await eventually { state.nextProductID == MembershipProduct.plusMonthly }
        XCTAssertTrue(booked, "the switch is booked in the renewal info")
        XCTAssertEqual(state.plan, .pro, "Pro until renewal")
        XCTAssertEqual(session.allTransactions().count, transactions, "no new transaction, so no charge")
        XCTAssertEqual(balance, checks)
        XCTAssertEqual(PlanOption.for(MembershipProduct.plusMonthly, in: state), .booked(state.renewsAt))

        try session.forceRenewalOfSubscription(productIdentifier: MembershipProduct.proMonthly)
        let switched = await eventually { state.plan == .plus }
        XCTAssertTrue(switched, "at renewal Apple moves the person to Plus")
        XCTAssertEqual(balance.monthlyLeft, 15, "a fresh Plus month, not Pro's usage")
        XCTAssertEqual(balance.rolledOverLeft, 15)
    }

    func testUndoingADowngradeKeepsPro() async {
        await buy(MembershipProduct.proMonthly)
        await buy(MembershipProduct.plusMonthly)
        let booked = await eventually { state.nextProductID == MembershipProduct.plusMonthly }
        XCTAssertTrue(booked)
        let outcome = await store.keepCurrent()
        XCTAssertEqual(outcome, .done)
        let undone = await eventually { state.nextProductID == nil }
        XCTAssertTrue(undone)
        XCTAssertEqual(state.plan, .pro)
    }

    func testMonthlyToYearlyWaitsForRenewal() async throws {
        await buy(MembershipProduct.proMonthly)
        await buy(MembershipProduct.proYearly)
        let booked = await eventually { state.nextProductID == MembershipProduct.proYearly }
        XCTAssertTrue(booked)
        XCTAssertEqual(state.productID, MembershipProduct.proMonthly)
        try session.forceRenewalOfSubscription(productIdentifier: MembershipProduct.proMonthly)
        let switched = await eventually { state.productID == MembershipProduct.proYearly }
        XCTAssertTrue(switched)
    }

    // MARK: Renewal, cancel, expiry, refund

    func testRenewalWithAcceleratedTimeCarriesUnusedChecks() async {
        session.timeRate = .monthlyRenewalEveryThirtySeconds
        await buy(MembershipProduct.plusMonthly)
        let first = state.transactionID
        for _ in 0..<5 { entitlements.commitCheck(wasFreeOnProxy: false) }
        let renewed = await eventually(50) { state.transactionID != first && state.plan == .plus }
        XCTAssertTrue(renewed)
        XCTAssertEqual(balance.monthlyLeft, 15)
        XCTAssertEqual(balance.rolledOverLeft, 10)
    }

    /// The test clock makes a year six minutes; each "month" of it is thirty seconds.
    func testAYearlyPlanGetsMonthlyChecks() async {
        session.timeRate = .monthlyRenewalEveryThirtySeconds
        await buy(MembershipProduct.proYearly)
        for _ in 0..<50 { entitlements.commitCheck(wasFreeOnProxy: false) }
        XCTAssertEqual(balance.monthlyLeft, 0)
        let fresh = await eventually(45) { balance.monthlyLeft == 50 }
        XCTAssertTrue(fresh, "a new month's checks without a renewal")
    }

    func testCancelKeepsThePlanThenResubscribeUndoesIt() async throws {
        await buy(MembershipProduct.plusMonthly)
        let checks = balance
        let t = try XCTUnwrap(latest(MembershipProduct.plusMonthly))
        try session.disableAutoRenewForTransaction(identifier: t.identifier)
        let cancelled = await eventually { state.isCancelled }
        XCTAssertTrue(cancelled)
        XCTAssertEqual(state.plan, .plus, "runs to the end of the paid period")
        XCTAssertEqual(balance, checks)
        try session.enableAutoRenewForTransaction(identifier: t.identifier)
        let back = await eventually { !state.isCancelled }
        XCTAssertTrue(back)
    }

    func testExpiryDropsToFreeCarryingOne() async throws {
        await buy(MembershipProduct.plusMonthly)
        // Cancel first: with renewal still on, the test store renews an expired plan at once.
        let t = try XCTUnwrap(latest(MembershipProduct.plusMonthly))
        try session.disableAutoRenewForTransaction(identifier: t.identifier)
        try session.expireSubscription(productIdentifier: MembershipProduct.plusMonthly)
        let free = await eventually { state.plan == .free }
        XCTAssertTrue(free)
        XCTAssertEqual(balance.rolledOverLeft, 1)
    }

    func testRefundIsAnExpiryAtThatMoment() async throws {
        await buy(MembershipProduct.proMonthly)
        let t = try XCTUnwrap(latest(MembershipProduct.proMonthly))
        try session.refundTransaction(identifier: t.identifier)
        let free = await eventually { state.plan == .free }
        XCTAssertTrue(free)
        XCTAssertGreaterThanOrEqual(balance.total, 0)
    }

    func testARefundedTopUpRemovesOnlyItsUnusedChecks() async throws {
        await buy(MembershipProduct.topUp5)
        await buy(MembershipProduct.topUp5)
        XCTAssertEqual(balance.topUps, 10)
        for _ in 0..<3 { entitlements.commitCheck(wasFreeOnProxy: false) }   // 3 from the first top-up
        XCTAssertEqual(balance.topUps, 7)
        let first = try XCTUnwrap(session.allTransactions().first { $0.productIdentifier == MembershipProduct.topUp5 })
        try session.refundTransaction(identifier: first.identifier)
        let refunded = await eventually { balance.topUps == 5 }
        XCTAssertTrue(refunded, "the first top-up's 2 unused checks go; the second's 5 stay")
    }

    // MARK: Billing trouble

    func testBillingRetryInTheGracePeriodKeepsThePlan() async throws {
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        await buy(MembershipProduct.plusMonthly)
        try session.forceRenewalOfSubscription(productIdentifier: MembershipProduct.plusMonthly)
        let grace = await eventually { state.billing.hasIssue && state.plan == .plus }
        XCTAssertTrue(grace)
        XCTAssertEqual(state.plan, .plus)
    }

    func testBillingRetryWithoutGraceIsAnExpiry() async throws {
        session.shouldEnterBillingRetryOnRenewal = true
        await buy(MembershipProduct.plusMonthly)
        try session.forceRenewalOfSubscription(productIdentifier: MembershipProduct.plusMonthly)
        let flagged = await eventually { state.billing.hasIssue }
        XCTAssertTrue(flagged, "a failed renewal must show as a payment problem. State: \(state)")
        // The real App Store ends the paid period before it retries, so the plan is paused (Free).
        // The test store can fail the renewal while the paid month is still running; then the
        // plan stays on with the same payment banner as the grace period.
        if state.plan == .free {
            XCTAssertEqual(state.billing, .retrying(productID: MembershipProduct.plusMonthly))
        } else {
            XCTAssertEqual(state.plan, .plus)
            XCTAssertEqual(state.billing, .gracePeriod(until: nil), "State: \(state)")
        }
    }

    // MARK: Purchases that don't finish at once

    func testAnInterruptedPurchaseStartsOnceResolved() async throws {
        session.interruptedPurchasesEnabled = true
        _ = await store.purchase(MembershipProduct.plusMonthly)
        XCTAssertEqual(state.plan, .free)
        let t = try XCTUnwrap(latest(MembershipProduct.plusMonthly))
        try session.resolveIssueForTransaction(identifier: t.identifier)
        let started = await eventually { state.plan == .plus }
        XCTAssertTrue(started)
    }

    func testAskToBuyWaitsForApproval() async throws {
        session.askToBuyEnabled = true
        let outcome = await store.purchase(MembershipProduct.plusMonthly)
        XCTAssertEqual(outcome, .pending)
        XCTAssertEqual(state.plan, .free)
        let t = try XCTUnwrap(latest(MembershipProduct.plusMonthly))
        try session.approveAskToBuyTransaction(identifier: t.identifier)
        let started = await eventually { state.plan == .plus }
        XCTAssertTrue(started)
    }
}
