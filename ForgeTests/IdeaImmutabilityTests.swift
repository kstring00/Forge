import XCTest
import SwiftData
@testable import Forge

/// Brief §12: original idea text can never be edited or lost.
/// Compile-time: `Idea.originalText` has a private setter, so
/// `idea.originalText = "x"` does not compile outside the class.
/// Runtime: it survives every other edit, save and fetch unchanged.
@MainActor
final class IdeaImmutabilityTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        try ModelContainer.forge(inMemory: true).mainContext
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

    func testSuggestedTitleTruncatesOnWordBoundary() {
        let long = String(repeating: "word ", count: 30)
        let title = Idea.suggestedTitle(from: long)
        XCTAssertLessThanOrEqual(title.count, 61)
        XCTAssertTrue(title.hasSuffix("…"))
        XCTAssertEqual(Idea.suggestedTitle(from: "\n\n   \n"), "Untitled idea")
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
