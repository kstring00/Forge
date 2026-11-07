import XCTest
@testable import ForgeCore

final class ExplorePromptsTests: XCTestCase {
    func testSixPromptsCoverTheBriefsQuestions() {
        XCTAssertEqual(ExplorePrompts.all.count, 6)
        XCTAssertEqual(ExplorePrompts.keys, ["problem", "who", "today", "why", "tiny", "kills"])
        XCTAssertEqual(Set(ExplorePrompts.keys).count, 6)
    }

    func testEveryPromptIsComplete() {
        for p in ExplorePrompts.all {
            XCTAssertTrue(p.question.hasSuffix("?"), p.key)
            XCTAssertFalse(p.hint.isEmpty, p.key)
            XCTAssertFalse(ExplorePrompts.isAIKey(p.key))
        }
    }

    func testAIKeysAreDistinctFromPromptKeys() {
        XCTAssertTrue(ExplorePrompts.isAIKey("ai.expand"))
        XCTAssertNil(ExplorePrompts.prompt(for: "ai.expand"))
        XCTAssertEqual(ExplorePrompts.aiLabel(for: "ai.openQuestions"), "Open questions")
        XCTAssertEqual(ExplorePrompts.aiLabel(for: "ai.something"), "Something")
    }
}
