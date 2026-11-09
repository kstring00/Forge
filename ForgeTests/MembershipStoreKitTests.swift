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

    override func setUp() async throws {
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
        entitlements = LocalEntitlements(defaults: UserDefaults(suiteName: "skt-\(UUID().uuidString)")!)
        // Use the free first check and Free's own monthly one, so nothing carries in from Free.
        entitlements.commitCheck(wasFreeOnProxy: false)
        entitlements.commitCheck(wasFreeOnProxy: false)
        store = MembershipStore(entitlements: entitlements)
        await store.start()
    }

    override func tearDown() async throws {
        session.clearTransactions()
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

    private func buy(_ id: String) async {
        let outcome = await store.purchase(id)
        XCTAssertEqual(outcome, .done, "buying \(id): \(store.message ?? "")")
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
        XCTAssertEqual(balance.monthlyLeft, 60)
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
        for _ in 0..<60 { entitlements.commitCheck(wasFreeOnProxy: false) }
        XCTAssertEqual(balance.monthlyLeft, 0)
        let fresh = await eventually(45) { balance.monthlyLeft == 60 }
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
        let paused = await eventually { state.plan == .free }
        XCTAssertTrue(paused)
        XCTAssertEqual(state.billing, .retrying(productID: MembershipProduct.plusMonthly))
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
