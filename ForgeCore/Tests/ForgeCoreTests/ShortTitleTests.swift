import XCTest
@testable import ForgeCore

final class ShortTitleTests: XCTestCase {
    func testFirstClauseFillerStrippedAndCapped() {
        XCTAssertEqual(ShortTitle.make(from: "If what if there was an app that helped me gauge my ideas, and argued about them"), "App that helped me gauge my ideas")
        XCTAssertEqual(ShortTitle.make(from: "A weekend website-care service for RV parks along one highway corridor. Most owners…"), "Weekend website-care service for RV parks", "seven words would end on \"along\"")
        XCTAssertEqual(ShortTitle.make(from: "First line is the title\nSecond line is detail"), "First line is the title")
        XCTAssertEqual(ShortTitle.make(from: "Dog walking for seniors"), "Dog walking for seniors")
        XCTAssertEqual(ShortTitle.make(from: "\n\n  \n"), "Untitled idea")
        XCTAssertLessThanOrEqual(ShortTitle.wordCount(ShortTitle.make(from: String(repeating: "word ", count: 30))), 7)
    }

    func testClampKeepsTwoToSevenWordsWithoutADanglingJoiner() {
        XCTAssertEqual(ShortTitle.clamp("Clinic-issued ID tags for the"), "Clinic-issued ID tags")
        XCTAssertEqual(ShortTitle.clamp("\"Tap-to-read tags sold to ABA clinics.\""), "Tap-to-read tags sold to ABA clinics")
        XCTAssertNil(ShortTitle.clamp("Tags"))
    }

    /// Decision 0044: up to seven words, cut at a word, never ending on a connecting word.
    func testSevenWordsAndNeverEndingOnAConnectingWord() {
        XCTAssertEqual(ShortTitle.make(from: "Weekend site care for RV parks"), "Weekend site care for RV parks")
        XCTAssertEqual(ShortTitle.clamp("Weekend site care for RV parks"), "Weekend site care for RV parks")
        XCTAssertEqual(ShortTitle.clamp("Meal prep for night shift nurses with kids at home"), "Meal prep for night shift nurses")
        XCTAssertEqual(ShortTitle.clamp("A booking page for fishing charters and their guests"), "A booking page for fishing charters")
        XCTAssertEqual(ShortTitle.clamp("One two three four five six of eight"), "One two three four five six")
        for text in ["Voice notes turned into estimates for small roofing crews in Texas", "Horse boarding directory with reviews and prices for owners"] {
            let t = ShortTitle.make(from: text)
            XCTAssertLessThanOrEqual(ShortTitle.wordCount(t), 7)
            XCTAssertFalse(["for", "with", "of", "and"].contains(t.split(separator: " ").last.map(String.init)?.lowercased() ?? ""), t)
        }
    }
}
