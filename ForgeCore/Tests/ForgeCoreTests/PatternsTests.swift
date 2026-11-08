import XCTest
@testable import ForgeCore

final class PatternsTests: XCTestCase {
    private func r(_ s: Sphere, _ v: VerdictKind, _ key: String, _ c: RulingChoice, _ o: RulingOutcome, score: Int? = nil) -> SettledRuling {
        SettledRuling(sphere: s, verdict: v, criterionKey: key, choice: c, outcome: o, userScore: score)
    }

    func testNothingIsSaidUnderThreeOutcomes() {
        let p = Patterns([r(.strategist, .offTrack, "A3", .disagree, .sphereRight), r(.customer, .cantTell, "A2", .findOut, .userRight)])
        XCTAssertFalse(p.hasEnough)
        XCTAssertEqual(p.outcomes, 2)
        XCTAssertTrue(p.summary(lens: Lenses.business).isEmpty)
        XCTAssertEqual(p.aboutNote(lens: Lenses.business), "")
    }

    func testRecordAgainstEachSphereAndTendencies() {
        let p = Patterns([
            r(.strategist, .offTrack, "A3", .disagree, .sphereRight, score: 4),
            r(.strategist, .offTrack, "A3", .disagree, .sphereRight, score: 5),
            r(.strategist, .onTrack, "A5", .agree, .sphereRight, score: 3),
            r(.investor, .onTrack, "A5", .disagree, .userRight, score: 2),
            r(.customer, .cantTell, "A2", .findOut, .unsettled),
        ])
        XCTAssertTrue(p.hasEnough)
        XCTAssertEqual(p.outcomes, 4, "unsettled rulings are not outcomes")
        let strategist = p.spheres.first { $0.sphere == .strategist }!
        XCTAssertEqual(strategist.overruled, 2)
        XCTAssertEqual(strategist.sphereRight, 3)
        XCTAssertEqual(strategist.userRight, 0)
        XCTAssertEqual(p.mostUnderrated?.sphere, .strategist)
        XCTAssertEqual(p.mostOverruledRightly?.sphere, .investor)
        XCTAssertEqual(p.tendencies.first?.key, "A3")
        XCTAssertEqual(p.tendencies.first?.lean, 2)
        let lines = p.summary(lens: Lenses.business)
        XCTAssertTrue(lines.contains { $0.contains("overrule the Strategist") && $0.contains("3 of 3") })
        XCTAssertTrue(lines.contains { $0.contains("Differentiation") && $0.contains("higher") })
    }

    func testAboutNoteStaysUnderEightyWordsAndNamesNoIDs() {
        let many = (0..<30).map { i in r(Sphere.phase3Panel[i % 5], i % 2 == 0 ? .offTrack : .onTrack, "A\(i % 6 + 1)", .disagree, .sphereRight, score: i % 2 == 0 ? 5 : 1) }
        let note = Patterns(many).aboutNote(lens: Lenses.business)
        XCTAssertFalse(note.isEmpty)
        XCTAssertLessThanOrEqual(note.split(separator: " ").count, 80)
        XCTAssertFalse(IDScrub.containsID(note))
    }
}
