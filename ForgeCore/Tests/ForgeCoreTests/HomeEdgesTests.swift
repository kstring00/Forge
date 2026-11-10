import XCTest
@testable import ForgeCore

final class HomeEdgesTests: XCTestCase {
    func testTheCoverOverTheStatusBarBuildsAsHomeScrolls() {
        XCTAssertEqual(HomeEdges.topCover(scrolled: 0), 0, "at the top the sky shows")
        XCTAssertEqual(HomeEdges.topCover(scrolled: -30), 0, "pulling down past the top shows nothing")
        XCTAssertEqual(HomeEdges.topCover(scrolled: 20), 0.5)
        XCTAssertEqual(HomeEdges.topCover(scrolled: 40), 1)
        XCTAssertEqual(HomeEdges.topCover(scrolled: 900), 1, "solid for the rest of the list")
        XCTAssertEqual(HomeEdges.topCover(scrolled: .nan), 0)
        XCTAssertEqual(HomeEdges.topCover(scrolled: 10, over: 0), 1)
    }

    func testTheCoverMovesInTenthsSoScrollingDoesNotRedrawEveryFrame() {
        let values = Set(stride(from: 0.0, through: 400, by: 0.5).map { HomeEdges.topCover(scrolled: $0) })
        XCTAssertEqual(values.count, 11)
        XCTAssertEqual(HomeEdges.topCover(scrolled: 13), HomeEdges.topCover(scrolled: 13.4))
    }

    func testTheHeaderStartsBelowTheStatusBarOnEveryPhone() {
        XCTAssertEqual(HomeEdges.headerTop(safeAreaTop: 20), 60, "iPhone SE: the design's spacing")
        XCTAssertEqual(HomeEdges.headerTop(safeAreaTop: 47), 60)
        XCTAssertEqual(HomeEdges.headerTop(safeAreaTop: 59), 65, "Dynamic Island: just below it")
        XCTAssertEqual(HomeEdges.headerTop(safeAreaTop: 62), 68)
        XCTAssertEqual(HomeEdges.headerTop(safeAreaTop: -4), 60)
        for inset in stride(from: 0.0, through: 80, by: 1) {
            XCTAssertGreaterThan(HomeEdges.headerTop(safeAreaTop: inset), inset)
        }
    }

    func testTheLastRowStopsClearOfTheFadeTheButtonAndTheTabBar() {
        let fade = HomeEdges.bottomFade(button: 64, inset: 16)
        XCTAssertEqual(fade, 104)
        XCTAssertGreaterThan(fade, 64 + 16, "the fade starts above the button")
        XCTAssertGreaterThan(HomeEdges.listBottomPadding(button: 64, inset: 16), fade)
    }

    func testTheFadeOnlyGetsMoreSolidAndIsHalfSolidByTheButton() {
        let stops = HomeEdges.bottomFadeStops
        XCTAssertEqual(stops.first?.opacity, 0)
        XCTAssertEqual(stops.first?.location, 0)
        XCTAssertEqual(stops.last?.opacity, 1)
        XCTAssertEqual(stops.last?.location, 1)
        for (a, b) in zip(stops, stops.dropFirst()) {
            XCTAssertLessThan(a.location, b.location)
            XCTAssertLessThanOrEqual(a.opacity, b.opacity)
        }
        // The button's top edge, as a share of the fade's height.
        let buttonTop = 24.0 / HomeEdges.bottomFade(button: 64, inset: 16)
        let atButton = stops.last { $0.location <= buttonTop + 0.06 }
        XCTAssertGreaterThanOrEqual(atButton?.opacity ?? 0, 0.5)
    }
}
