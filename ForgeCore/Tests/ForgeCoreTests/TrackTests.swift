import XCTest
@testable import ForgeCore

final class TrackTests: XCTestCase {
    func testEveryStageMapsOntoOneTrackExceptArchived() {
        XCTAssertEqual(Stage.capture.track, .idea)
        XCTAssertEqual(Stage.explore.track, .idea)
        XCTAssertEqual(Stage.evaluate.track, .formation)
        XCTAssertEqual(Stage.build.track, .reality)
        XCTAssertEqual(Stage.launch.track, .reality)
        XCTAssertNil(Stage.archived.track)
    }

    func testEntryStagesRoundTrip() {
        for track in Track.allCases {
            XCTAssertEqual(track.entryStage.track, track)
        }
    }

    func testOrderAndCopy() {
        XCTAssertEqual(Track.allCases.map(\.displayName), ["Idea", "Formation", "Reality"])
        XCTAssertEqual(Track.idea.next, .formation)
        XCTAssertEqual(Track.formation.next, .reality)
        XCTAssertNil(Track.reality.next)
        for track in Track.allCases {
            XCTAssertFalse(track.tagline.contains("!"))
            XCTAssertTrue(track.tagline.hasSuffix("."))
        }
    }
}
