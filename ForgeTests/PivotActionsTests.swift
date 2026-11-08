import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Decision 0024: a what-if becomes a sibling idea only on the user's tap,
/// carries the pivot lineage, and is never checked on its own.
@MainActor
final class PivotActionsTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    func testSpawnMakesAnUncheckedSiblingWithLineage() throws {
        let parent = Idea(originalText: "Web care for RV parks, sold one park at a time")
        parent.lensType = .business
        store.context.insert(parent)
        let check = RealityCheck(verdict: .compete, summary: "crowded")
        let pivot = PivotIdea(whatIf: "What if you sold through the park owners' association?", pivotType: .channel, fixes: "A5",
                              why: "Three parks name the same association.", firstTest: "Email the association.")
        check.pivots = [pivot]
        parent.realityChecks.append(check)
        try store.context.save()

        let child = PivotActions.spawn(pivot, from: parent, check: check, in: store.context)

        XCTAssertEqual(child.originalText, pivot.whatIf, "the what-if is the new idea's own words")
        XCTAssertEqual(child.origin, .pivoted)
        XCTAssertEqual(child.pivotType, .channel)
        XCTAssertEqual(child.pivotOf?.id, parent.id)
        XCTAssertEqual(child.lensType, .business)
        XCTAssertEqual(child.stage, .capture)
        XCTAssertTrue(child.realityChecks.isEmpty, "never checked on its own")
        XCTAssertEqual(child.track, .idea)
        XCTAssertTrue(parent.pivots.contains { $0.id == child.id })
        XCTAssertEqual(check.pivots.first?.spawnedIdeaID, child.id, "the card remembers which idea it made")

        let again = PivotActions.spawn(pivot, from: parent, check: check, in: store.context)
        XCTAssertEqual(again.id, child.id, "a second tap opens the same idea instead of making another")
    }
}
