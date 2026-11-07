import XCTest
import SwiftData
import ForgeCore
@testable import Forge

@MainActor
final class ExploreActionsTests: XCTestCase {
    func testAnswersUpsertPerPromptAndMoveStageToExplore() throws {
        let store = try TestStore()
        let context = store.context
        let idea = Idea(originalText: "x")
        context.insert(idea)
        XCTAssertEqual(idea.stage, .capture)

        ExploreActions.answer("  Double bookings at small marinas ", promptKey: "problem", on: idea)
        XCTAssertEqual(idea.stage, .explore)
        XCTAssertEqual(ExploreActions.latest(for: "problem", on: idea)?.userText, "Double bookings at small marinas")
        XCTAssertEqual(ExploreActions.answeredCount(on: idea), 1)

        ExploreActions.answer("Harbor masters", promptKey: "problem", on: idea)
        XCTAssertEqual(idea.explorations.count, 1, "same prompt updates in place")
        XCTAssertEqual(ExploreActions.latest(for: "problem", on: idea)?.userText, "Harbor masters")

        ExploreActions.answer("", promptKey: "who", on: idea)
        XCTAssertEqual(ExploreActions.answeredCount(on: idea), 1, "empty answers don't count")
        try context.save()
    }

    func testAcceptedAINotesAreSeparateAndConfirmed() throws {
        let store = try TestStore()
        let context = store.context
        let idea = Idea(originalText: "x")
        idea.stage = .evaluate
        context.insert(idea)

        let note = ExploreActions.acceptAI(text: "Clearer version", promptKey: "ai.expand", on: idea)
        XCTAssertTrue(note.confirmed)
        XCTAssertEqual(note.aiText, "Clearer version")
        XCTAssertEqual(note.userText, "")
        XCTAssertEqual(idea.stage, .evaluate, "accepting AI notes never moves a later stage backwards")
        XCTAssertEqual(ExploreActions.aiNotes(on: idea).count, 1)
        XCTAssertEqual(ExploreActions.answeredCount(on: idea), 0)

        ExploreActions.acceptAI(text: "Second pass", promptKey: "ai.expand", on: idea)
        XCTAssertEqual(ExploreActions.aiNotes(on: idea).count, 2, "AI notes accumulate; nothing is overwritten")
        XCTAssertEqual(idea.originalText, "x")
    }
}
