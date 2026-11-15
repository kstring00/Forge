import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Decision 0023: the panel's take is the newest check; a re-check replaces
/// it on the page and the earlier one stays in History.
@MainActor
final class PanelsTakeTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    func testRecheckReplacesTheTakeAndKeepsTheOld() throws {
        let idea = Idea(originalText: "Weekend RV park site care on one corridor")
        store.context.insert(idea)
        let first = RealityCheck(verdict: .cantTell, summary: "first")
        first.createdAt = Date(timeIntervalSinceNow: -3600)
        idea.realityChecks.append(first)
        let second = RealityCheck(verdict: .buildIt, summary: "second")
        idea.realityChecks.append(second)
        try store.context.save()

        XCTAssertEqual(idea.latestRealityCheck?.verdict, .buildIt, "the page shows the newest take")
        XCTAssertEqual(PanelsTake.history(for: idea).map(\.summary), ["second", "first"], "History keeps both, newest first")
    }

    func testOrbStatesReadLikeTheArc() {
        let verdicts: [(Sphere, VerdictKind)] = [(.customer, .cantTell), (.investor, .onTrack), (.skeptic, .offTrack)]
        XCTAssertEqual(PanelsTake.orbState(for: .steward, verdicts: verdicts, working: [], isWorking: false), .dormant)
        XCTAssertEqual(PanelsTake.orbState(for: .investor, verdicts: verdicts, working: [], isWorking: false), .verdict(.onTrack))
        XCTAssertEqual(PanelsTake.orbState(for: .builder, verdicts: verdicts, working: [], isWorking: false), .idle, "no verdict yet reads idle")
        XCTAssertEqual(PanelsTake.orbState(for: .customer, verdicts: verdicts, working: [.customer], isWorking: true), .working, "a re-check lights the working orbs")
        XCTAssertEqual(PanelsTake.orbState(for: .investor, verdicts: verdicts, working: [.customer], isWorking: true), .idle)
    }
}
