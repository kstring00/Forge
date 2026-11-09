import XCTest
import ForgeCore
@testable import Forge

/// Decision 0032: the local ledger behind `EntitlementService`.
@MainActor
final class EntitlementsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var clock = Date(timeIntervalSince1970: 1_793_000_000)   // Nov 2026

    override func setUp() {
        defaults = UserDefaults(suiteName: "EntitlementsTests-\(UUID().uuidString)")
    }

    private func make() -> LocalEntitlements { LocalEntitlements(defaults: defaults, now: { [unowned self] in clock }) }

    func testFreeThenPlusThenTopUp() {
        let e = make()
        XCTAssertEqual(e.state.plan, .free)
        XCTAssertTrue(e.balance.firstFreeAvailable)
        XCTAssertTrue(e.canStartCheck(inFlight: 0))
        e.commitCheck(wasFreeOnProxy: false)          // the free first check
        e.commitCheck(wasFreeOnProxy: false)          // Free's one a month
        XCTAssertFalse(e.canStartCheck(inFlight: 0), "out of checks on Free")
        XCTAssertTrue(e.has(.library), "the Library is on every plan (decision 0042)")
        XCTAssertFalse(e.has(.deepResearch))
        XCTAssertTrue(e.has(.whatIf), "Sparks are free on every plan (decision 0040)")

        e.apply(MembershipState(plan: .plus, isTrial: false, anchor: clock, productID: MembershipProduct.plusYearly, renewsAt: nil, founding: false), jws: [])
        XCTAssertFalse(e.has(.deepResearch), "deep research is Pro")
        XCTAssertEqual(e.balance.monthlyAllowance, 15)
        XCTAssertEqual(e.balance.monthlyLeft, 15, "a new plan starts a new period")

        e.creditTopUp(transactionID: "42", jws: "")
        e.creditTopUp(transactionID: "42", jws: "")
        XCTAssertEqual(e.balance.topUps, 5, "one purchase, credited once")
    }

    func testTheTrialIsCappedAndTheLedgerPersists() {
        let e = make()
        e.apply(MembershipState(plan: .plus, isTrial: true, anchor: clock, productID: MembershipProduct.plusYearly, renewsAt: nil, founding: false), jws: [])
        XCTAssertEqual(e.balance.monthlyAllowance, 5)
        e.commitCheck(wasFreeOnProxy: true)
        e.commitCheck(wasFreeOnProxy: false)
        let again = make()
        XCTAssertEqual(again.state.plan, .plus)
        XCTAssertEqual(again.balance.monthlyLeft, 4, "the free one cost nothing; the second used one of five")
    }
}
