import XCTest
@testable import ForgeCore

final class ScoringTests: XCTestCase {
    func testPotentialBounds() {
        XCTAssertEqual(Scoring.potential(scores: [1, 1, 1, 1, 1, 1]), 0)
        XCTAssertEqual(Scoring.potential(scores: [5, 5, 5, 5, 5, 5]), 100)
        XCTAssertEqual(Scoring.potential(scores: [3, 3, 3, 3, 3, 3]), 50)
    }

    func testPotentialRoundsToNearest() {
        // mean 3.5 → (2.5/4)*100 = 62.5 → 63 (Swift .rounded() is schoolbook)
        XCTAssertEqual(Scoring.potential(scores: [3, 4]), 63)
        // mean 2 → 25
        XCTAssertEqual(Scoring.potential(scores: [1, 3]), 25)
    }

    func testPotentialClampsOutOfRangeInput() {
        XCTAssertEqual(Scoring.potential(scores: [0, 9]), Scoring.potential(scores: [1, 5]))
    }

    func testPotentialEmptyIsZero() {
        XCTAssertEqual(Scoring.potential(scores: []), 0)
    }

    func testConfidenceBounds() {
        XCTAssertEqual(Scoring.confidence(evidenceLevels: [0, 0, 0]), 0)
        XCTAssertEqual(Scoring.confidence(evidenceLevels: [5, 5, 5]), 100)
        XCTAssertEqual(Scoring.confidence(evidenceLevels: [2, 3]), 50)
        XCTAssertEqual(Scoring.confidence(evidenceLevels: []), 0)
    }

    func testPotentialAndConfidenceAreIndependent() {
        // High enthusiasm, no evidence: potential high, confidence zero.
        XCTAssertEqual(Scoring.potential(scores: [5, 5, 5, 5, 5, 5]), 100)
        XCTAssertEqual(Scoring.confidence(evidenceLevels: [0, 0, 0, 0, 0, 0]), 0)
    }

    func testLowConfidenceLabel() {
        XCTAssertTrue(Scoring.isMostlyEnthusiasm(confidence: 39))
        XCTAssertFalse(Scoring.isMostlyEnthusiasm(confidence: 40))
    }

    func testNormalize() {
        XCTAssertEqual(Scoring.normalize(1, from: 1...5), 0)
        XCTAssertEqual(Scoring.normalize(5, from: 1...5), 100)
        XCTAssertEqual(Scoring.normalize(0, from: 0...5), 0)
        XCTAssertEqual(Scoring.normalize(7, from: 1...5), 100)
        XCTAssertEqual(Scoring.normalize(3, from: 3...3), 0)
    }

    func testDemandScoreNeedsThreeIndependentPeople() {
        // One person at rung 4 does not move the score.
        XCTAssertEqual(Scoring.demandScore(peopleAtRung: [4: 1]), 1)
        XCTAssertEqual(Scoring.demandScore(peopleAtRung: [2: 3, 4: 1]), 2)
        XCTAssertEqual(Scoring.demandScore(peopleAtRung: [3: 3]), 3)
        XCTAssertEqual(Scoring.demandScore(peopleAtRung: [5: 3]), 5)
        // Rungs 0 and 1 are worth nothing: score floor is 1.
        XCTAssertEqual(Scoring.demandScore(peopleAtRung: [1: 50]), 1)
        XCTAssertEqual(Scoring.demandScore(peopleAtRung: [:]), 1)
    }

    func testConfidenceBreakdownSumsTo100() {
        let b = ConfidenceBreakdown(classes: [.userVerified, .aiFound, .assumption])
        XCTAssertEqual(b.verifiedPercent + b.aiFoundPercent + b.assumptionPercent, 100)
        let e = ConfidenceBreakdown(classes: [])
        XCTAssertEqual(e, ConfidenceBreakdown(classes: []))
        XCTAssertEqual(e.verifiedPercent, 0)
        let all = ConfidenceBreakdown(classes: [.userVerified, .userVerified])
        XCTAssertEqual(all.verifiedPercent, 100)
    }
}
