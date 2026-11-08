import XCTest
@testable import ForgeCore

final class QuotesTests: XCTestCase {
    func testEveryQuoteIsAttributed() {
        XCTAssertEqual(Quotes.all.count, 9)
        for q in Quotes.all {
            XCTAssertFalse(q.text.isEmpty)
            XCTAssertFalse(q.author.isEmpty)
            XCTAssertFalse(q.text.hasPrefix("\""), "quotes are stored bare; the view adds the marks")
        }
        XCTAssertEqual(Quotes.all.filter { $0.kind == .scripture }.count, 4)
        XCTAssertEqual(Quotes.all.first?.attribution, "Steve Jobs · to the Macintosh team, 1983")
        XCTAssertEqual(Quotes.all.last?.attribution, "Proverbs 16:9 · NIV")
    }

    func testRotatesDailyWithinTheSetting() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let d1 = cal.date(from: DateComponents(year: 2026, month: 11, day: 8))!
        let d2 = cal.date(from: DateComponents(year: 2026, month: 11, day: 9))!
        XCTAssertEqual(Quotes.forDay(d1, setting: .all, calendar: cal), Quotes.forDay(d1, setting: .all, calendar: cal))
        XCTAssertNotEqual(Quotes.forDay(d1, setting: .all, calendar: cal), Quotes.forDay(d2, setting: .all, calendar: cal))
        for day in 0..<12 {
            let d = cal.date(byAdding: .day, value: day, to: d1)!
            XCTAssertEqual(Quotes.forDay(d, setting: .scripture, calendar: cal)?.kind, .scripture)
            XCTAssertEqual(Quotes.forDay(d, setting: .secular, calendar: cal)?.kind, .secular)
        }
        XCTAssertNil(Quotes.forDay(d1, setting: .off, calendar: cal))
        XCTAssertEqual(Quotes.dayKey(d1, calendar: cal), "2026-11-08")
    }
}
