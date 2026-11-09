import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Decision 0041: the plan as the proxy sends it, saved on the idea, and what
/// the plan page says moved since.
@MainActor
final class LaunchPlanAppTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    private let json = """
    {"oneLine":"A tap-to-read tag sold to ABA clinics.","forWho":"ABA clinics.",
     "proven":[{"text":"3 directors said lost cards are weekly","sourceID":"11111111-1111-4111-8111-111111111111"}],
     "unproven":["No clinic has paid yet"],"riskiest":"Clinics pay for it",
     "days1to30":{"title":"Sell to 3 clinics","detail":"Visit three.","decide":"If 2 say yes, build."},
     "days31to60":{"title":"Build and pilot","detail":"First batch.","decide":"If parents use it, keep going."},
     "days61to90":{"title":"Launch and measure","detail":"Open orders.","decide":"If margins hold, grow."},
     "customerNoun":"clinics","stopRule":"If no clinic pays by day 45.","stewardNote":null}
    """

    func testAPlanFromTheProxyIsSavedOnTheIdeaAndReadBack() throws {
        let r = try JSONDecoder().decode(LaunchPlanResult.self, from: Data(json.utf8))
        let basis = LaunchPlan.Basis(conversations: 1, proofStep: 1, checkedAt: nil)
        let plan = PlanBuilder.plan(from: r, rationale: "Rests on three calls.", basis: basis)
        XCTAssertEqual(plan.phases.map(\.days), ["Days 1–30", "Days 31–60", "Days 61–90"])
        XCTAssertEqual(plan.phases[0].decide, "If 2 say yes, build.")
        XCTAssertNil(plan.stewardNote)

        let idea = Idea(originalText: "Clinic-issued ID tags handed to parents at intake")
        store.context.insert(idea)
        XCTAssertFalse(PlanBuilder.isEligible(idea), "nothing to stand on before the panel looks")
        idea.launchPlan = plan
        try store.context.save()
        XCTAssertEqual(idea.launchPlan, plan)
        XCTAssertEqual(idea.launchPlan?.proven.first?.sourceID, UUID(uuidString: "11111111-1111-4111-8111-111111111111"))

        // Nothing logged on this idea since: one conversation fewer than the basis says, nothing new.
        XCTAssertEqual(PlanBuilder.changes(since: plan, for: idea), [])
    }

    func testEntitlementsSpendAPlansChecksAtOnce() {
        let defaults = UserDefaults(suiteName: "plans-\(UUID().uuidString)")!
        let e = LocalEntitlements(defaults: defaults)
        e.commitCheck(wasFreeOnProxy: false) // the free first check
        XCTAssertEqual(e.balance.total, 1, "Free: one check a month")
        XCTAssertFalse(e.canSpend(PlanCost.newPlan, inFlight: 0))
        e.creditTopUp(transactionID: "t1", jws: "")
        XCTAssertTrue(e.canSpend(PlanCost.newPlan, inFlight: 0))
        e.spend(PlanCost.newPlan)
        XCTAssertEqual(e.balance.total, 3)
    }
}
