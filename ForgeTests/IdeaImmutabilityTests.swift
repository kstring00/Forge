import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Brief §12: original idea text can never be edited or lost.
/// Compile-time: `Idea.originalText` has a private setter, so
/// `idea.originalText = "x"` does not compile outside the class.
/// Runtime: it survives every other edit, save and fetch unchanged.
@MainActor
final class IdeaImmutabilityTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    private func makeContext() throws -> ModelContext {
        store.context
    }

    func testOriginalTextSurvivesEditsSaveAndFetch() throws {
        let context = try makeContext()
        let raw = "  a rough thought,\nwith odd   spacing and a trailing space "
        let idea = Idea(originalText: raw)
        context.insert(idea)
        try context.save()

        idea.title = "Changed title"
        idea.aiSummary = "An AI summary"
        idea.aiSummaryConfirmed = true
        idea.tags = ["x"]
        idea.notes = "some notes"
        idea.stage = .evaluate
        idea.lensType = .business
        idea.archive()
        idea.unarchive()
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<Idea>())
        XCTAssertEqual(fetched.count, 1)
        XCTAssertEqual(fetched.first?.originalText, raw, "original text must be byte-for-byte what was captured, not even trimmed")
    }

    func testTitleIsDerivedButOriginalIsNot() {
        let idea = Idea(originalText: "First line is the title\nSecond line is detail")
        XCTAssertEqual(idea.title, "First line is the title")
        XCTAssertEqual(idea.originalText, "First line is the title\nSecond line is detail")
    }

    func testSuggestedTitleIsTwoToSevenWords() {
        let long = String(repeating: "word ", count: 30)
        XCTAssertLessThanOrEqual(ShortTitle.wordCount(Idea.suggestedTitle(from: long)), 7)
        XCTAssertEqual(Idea.suggestedTitle(from: "\n\n   \n"), "Untitled idea")
        let idea = Idea(originalText: "What if there was an app that tracked lost ID cards for clinics")
        XCTAssertEqual(idea.title, "App that tracked lost ID cards", "seven words would end on \"for\"")
        XCTAssertFalse(idea.titleEdited)
    }

    func testPivotKeepsOriginalUntouched() throws {
        let context = try makeContext()
        let parent = Idea(originalText: "parent text")
        let child = Idea(originalText: "variant text", origin: .pivoted)
        child.pivotType = .customerSegment
        child.pivotOf = parent
        context.insert(parent)
        context.insert(child)
        try context.save()
        XCTAssertEqual(parent.originalText, "parent text")
        XCTAssertEqual(parent.pivots.count, 1)
        XCTAssertEqual(child.pivotType, .customerSegment)
        XCTAssertEqual(child.origin, .pivoted)
    }
}
