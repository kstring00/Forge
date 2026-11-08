import XCTest
@testable import ForgeCore

final class ShortTitleTests: XCTestCase {
    func testFirstClauseFillerStrippedAndCapped() {
        XCTAssertEqual(ShortTitle.make(from: "If what if there was an app that helped me gauge my ideas, and argued about them"), "App that helped me gauge")
        XCTAssertEqual(ShortTitle.make(from: "A weekend website-care service for RV parks along one highway corridor. Most owners…"), "Weekend website-care service for RV")
        XCTAssertEqual(ShortTitle.make(from: "First line is the title\nSecond line is detail"), "First line is the title")
        XCTAssertEqual(ShortTitle.make(from: "Dog walking for seniors"), "Dog walking for seniors")
        XCTAssertEqual(ShortTitle.make(from: "\n\n  \n"), "Untitled idea")
        XCTAssertLessThanOrEqual(ShortTitle.wordCount(ShortTitle.make(from: String(repeating: "word ", count: 30))), 5)
    }

    func testClampKeepsTwoToFiveWordsWithoutADanglingJoiner() {
        XCTAssertEqual(ShortTitle.clamp("Clinic-issued ID tags for the"), "Clinic-issued ID tags")
        XCTAssertEqual(ShortTitle.clamp("\"Tap-to-read tags sold to ABA clinics.\""), "Tap-to-read tags sold to ABA")
        XCTAssertNil(ShortTitle.clamp("Tags"))
    }
}
