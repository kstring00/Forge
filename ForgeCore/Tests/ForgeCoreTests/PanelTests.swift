import XCTest
@testable import ForgeCore

final class PanelTests: XCTestCase {
    func testOnlyOnTrackAgainstOffTrackIsAConflict() {
        let pairs = Panel.conflicts([
            (.customer, .cantTell),
            (.investor, .onTrack),
            (.strategist, .offTrack),
            (.builder, .onTrack),
            (.skeptic, .cantTell),
        ])
        XCTAssertEqual(pairs, [SpherePair(.investor, .strategist), SpherePair(.strategist, .builder)])
        XCTAssertFalse(pairs.contains { $0.contains(.customer) || $0.contains(.skeptic) })
    }

    func testPairsAreUnorderedAndSortedByDistance() {
        XCTAssertEqual(SpherePair(.skeptic, .customer), SpherePair(.customer, .skeptic))
        XCTAssertEqual(SpherePair(.skeptic, .customer).a, .customer)
        XCTAssertEqual(SpherePair(.customer, .skeptic).span, 4)
        let pairs = Panel.conflicts([(.customer, .offTrack), (.investor, .onTrack), (.skeptic, .onTrack)])
        XCTAssertEqual(pairs.map(\.span), [1, 4])
    }

    func testAgreementAndCantTellDrawNoLines() {
        XCTAssertTrue(Panel.conflicts([(.customer, .onTrack), (.investor, .onTrack)]).isEmpty)
        XCTAssertTrue(Panel.conflicts([(.customer, .cantTell), (.investor, .offTrack)]).isEmpty)
        // A duplicate verdict for one Sphere does not invent a second position.
        XCTAssertTrue(Panel.conflicts([(.customer, .onTrack), (.customer, .offTrack)]).isEmpty)
    }

    func testTally() {
        let t = RoundTally([
            (.customer, .cantTell, .findOut),
            (.investor, .onTrack, .agree),
            (.strategist, .offTrack, .disagree),
            (.builder, .onTrack, nil),
            (.skeptic, .cantTell, nil),
        ])
        XCTAssertEqual(t.onTrack, 2)
        XCTAssertEqual(t.offTrack, 1)
        XCTAssertEqual(t.cantTell, 2)
        XCTAssertEqual(t.ruled, 3)
        XCTAssertEqual(t.unruled, 2)
        XCTAssertFalse(t.isComplete)
        XCTAssertEqual(t.splits.count, 2)
        XCTAssertEqual(t.panelLine, "The panel split 2 ways.")
        XCTAssertEqual(t.exceptions, 2)
        XCTAssertEqual(t.rulingsLine, "1 disagreement · 1 to find out")
        XCTAssertEqual(RoundTally([(.investor, .onTrack, nil), (.builder, .onTrack, .agree)]).rulingsLine, "Agreed with every voice")
        XCTAssertEqual(RoundTally([(.customer, .cantTell, .agree)]).panelLine, "Nobody could tell from the desk.")
        XCTAssertTrue(RoundTally([(.customer, .cantTell, .agree)]).isComplete)
    }
}
