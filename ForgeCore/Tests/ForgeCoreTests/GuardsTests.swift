import XCTest
@testable import ForgeCore

final class GuardsTests: XCTestCase {
    func testShortIdeasAreBlockedBeforeAnyCall() {
        XCTAssertEqual(IdeaGuard.check("Hello"), .tooShort)
        XCTAssertEqual(IdeaGuard.check("An app with in-app purchases"), .tooShort)
        XCTAssertEqual(IdeaGuard.check("one two three four five six seven"), .tooShort)
    }

    func testLongEnoughButAboutNothingIsBlocked() {
        XCTAssertEqual(IdeaGuard.check("Blue green yellow purple orange silver gold bronze copper iron"), .noSubject)
    }

    func testRealIdeasPass() {
        XCTAssertEqual(IdeaGuard.check("A website retainer for Texas RV parks. Most of these parks have a Facebook page and nothing else."), .ok)
        XCTAssertEqual(IdeaGuard.check("A bracelet for kids who can't say their name, so a stranger can tap it and call a parent."), .ok)
        // A personal idea with no problem and no person named is blocked too; the lens
        // menu (Growth, Creative) is the way past the panel for it.
        XCTAssertEqual(IdeaGuard.check("Start writing short stories again, one every Sunday morning before church."), .noSubject)
        XCTAssertEqual(IdeaGuard.check("I want to start writing short stories again, one every Sunday morning."), .ok)
        XCTAssertEqual(IdeaGuard.check("Teachers waste hours every week making the same worksheets by hand."), .ok)
    }

    func testNumberWords() {
        XCTAssertEqual(NumberWords.firstNumber(in: "Talk to five parents of non-verbal kids"), 5)
        XCTAssertEqual(NumberWords.firstNumber(in: "Send twenty cold messages to park owners"), 20)
        XCTAssertEqual(NumberWords.firstNumber(in: "Run 3 interviews, then 10 more"), 3)
        XCTAssertEqual(NumberWords.firstNumber(in: "Have three conversations, send 20 messages"), 3)
        XCTAssertEqual(NumberWords.firstNumber(in: "Put up the landing page"), nil)
        XCTAssertEqual(NumberWords.firstNumber(in: "Done by someone else"), nil, "'one' inside a word does not count")
    }

    func testIDScrubReplacesKnownIDsAndRemovesUnknownOnes() {
        let id = UUID(uuidString: "59E8DD62-1F1E-4C1B-9A0E-0A3F4C5D6E7F")!
        let titles = [id: "Northline pricing"]
        XCTAssertEqual(IDScrub.scrub("Three competitors charge $149 (source 59E8DD62-1F1E-4C1B-9A0E-0A3F4C5D6E7F).", titles: titles),
                       "Three competitors charge $149 (Northline pricing).")
        XCTAssertEqual(IDScrub.scrub("Three competitors charge $149 (source 59E8DD62-1F1E-4C1B-9A0E-0A3F4C5D6E7F)."),
                       "Three competitors charge $149.")
        XCTAssertEqual(IDScrub.scrub("Per 59E8DD62-1F1E-4C1B-9A0E-0A3F4C5D6E7F, owners pay monthly.", titles: titles),
                       "Per Northline pricing, owners pay monthly.")
        XCTAssertEqual(IDScrub.scrub("Owners pay monthly [id: 00000000-0000-0000-0000-000000000000], per two pages."),
                       "Owners pay monthly, per two pages.")
        XCTAssertEqual(IDScrub.scrub("No ids here."), "No ids here.")
        XCTAssertFalse(IDScrub.containsID("No ids here."))
    }
}
