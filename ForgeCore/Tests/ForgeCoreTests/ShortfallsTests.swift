import XCTest
@testable import ForgeCore

final class ShortfallsTests: XCTestCase {
    func testPicksCriteriaAtTwoOrBelowLowestFirst() {
        let scored = [
            ScoredCriterion(key: "A1", score: 4, evidenceLevel: 3),
            ScoredCriterion(key: "A2", score: 1, evidenceLevel: 1, peopleAtRung: 0),
            ScoredCriterion(key: "A3", score: 2, evidenceLevel: 1),
            ScoredCriterion(key: "A4", score: 5, evidenceLevel: 2),
        ]
        let s = Shortfalls.compute(scored, lens: Lenses.business)
        XCTAssertEqual(s.map(\.criterionKey), ["A2", "A3"])
        XCTAssertTrue(s[0].whatWouldHaveToBeTrue.contains("To score 2"))
        XCTAssertTrue(s[0].whatWouldHaveToBeTrue.contains("rung 1 with 0 of 3 people"))
        XCTAssertNotNil(s[0].suggestedStep)
    }

    func testFallsBackToLowestTwoWhenNothingIsLow() {
        let scored = ["A1", "A2", "A3", "A4", "A5", "A6"].enumerated().map {
            ScoredCriterion(key: $1, score: 3 + ($0 % 3), evidenceLevel: 2)
        }
        let s = Shortfalls.compute(scored, lens: Lenses.business)
        XCTAssertEqual(s.count, 2)
        XCTAssertEqual(s.map(\.score), [3, 3])
    }

    func testCheapestStepReachingRung() {
        let a2 = Lenses.criterion("A2", in: .business)!
        XCTAssertEqual(Shortfalls.cheapestStep(reaching: 3, in: a2)?.title, "Have five Mom Test conversations")
        XCTAssertEqual(Shortfalls.cheapestStep(reaching: 4, in: a2)?.title, "Sell the manual version to one customer")
        XCTAssertEqual(Shortfalls.cheapestStep(reaching: 5, in: a2)?.title, "See if they come back")
    }

    func testUnknownKeysAreSkipped() {
        let s = Shortfalls.compute([ScoredCriterion(key: "Z9", score: 1, evidenceLevel: 0)], lens: Lenses.business)
        XCTAssertTrue(s.isEmpty)
    }
}
