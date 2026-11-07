import XCTest
@testable import ForgeCore

final class NextMoveAndProjectionTests: XCTestCase {
    func testSuggestionRules() {
        XCTAssertEqual(NextMove.suggest(potential: 90, confidence: 90, triageFlagged: false, scoredCount: 5, criteriaCount: 6), .exploreFurther, "unscored criteria first")
        XCTAssertEqual(NextMove.suggest(potential: 20, confidence: 80, triageFlagged: false, scoredCount: 6, criteriaCount: 6), .revisitLater)
        XCTAssertEqual(NextMove.suggest(potential: 80, confidence: 10, triageFlagged: false, scoredCount: 6, criteriaCount: 6), .testRiskiestAssumption, "enthusiasm without evidence is a test, not a build")
        XCTAssertEqual(NextMove.suggest(potential: 80, confidence: 10, triageFlagged: true, scoredCount: 6, criteriaCount: 6), .revisitLater)
        XCTAssertEqual(NextMove.suggest(potential: 75, confidence: 65, triageFlagged: false, scoredCount: 6, criteriaCount: 6), .startBuilding)
        XCTAssertEqual(NextMove.suggest(potential: 60, confidence: 45, triageFlagged: false, scoredCount: 6, criteriaCount: 6), .buildSmallPrototype)
        XCTAssertEqual(NextMove.suggest(potential: 45, confidence: 45, triageFlagged: false, scoredCount: 6, criteriaCount: 6), .exploreFurther)
    }

    func testDefaultStepForTestUsesTheCriterionPlaybook() {
        let step = NextMove.defaultStep(.testRiskiestAssumption, lens: Lenses.business, lowestKey: "A2")
        XCTAssertEqual(step, "Have five Mom Test conversations")
        XCTAssertFalse(NextMove.defaultStep(.startBuilding, lens: Lenses.business, lowestKey: nil).isEmpty)
        for r in Recommendation.allCases { XCTAssertFalse(NextMove.shortLabel(r).isEmpty) }
    }

    func testProjectionArithmetic() {
        var p = Projection(pricePerUnit: 149, unitsYearOne: 12, verifiedUnits: 1)
        XCTAssertEqual(p.recurringPerMonth, 1788)
        XCTAssertEqual(p.assumedUnits, 11)
        XCTAssertEqual(p.verifiedFraction, 1.0 / 12.0, accuracy: 0.0001)
        p.verifiedUnits = 20
        XCTAssertEqual(p.verifiedFraction, 1)
        XCTAssertEqual(p.assumedUnits, 0)
        XCTAssertNil(Projection(pricePerUnit: 149).recurringPerMonth)
        XCTAssertTrue(Projection().isEmpty)
    }

    func testCompactCurrency() {
        XCTAssertEqual(Projection.compact(149), "$149")
        XCTAssertEqual(Projection.compact(1788), "$1.8k")
        XCTAssertEqual(Projection.compact(12_500), "$13k")
        XCTAssertEqual(Projection.compact(2_100_000), "$2.1M")
        XCTAssertEqual(Projection.compact(1000), "$1k")
    }
}
