import XCTest
@testable import ForgeCore

final class TriageTests: XCTestCase {
    func testThreeNosFlags() {
        let v = Triage.evaluate(["a": .no, "b": .no, "c": .no, "d": .yes])
        XCTAssertTrue(v.flagged)
        XCTAssertEqual(v.suggestion, .revisitLater)
    }

    func testTwoNosDoesNotFlag() {
        let v = Triage.evaluate(["a": .no, "b": .no, "c": .yes])
        XCTAssertFalse(v.flagged)
        XCTAssertNil(v.suggestion)
    }

    func testMostlyUnsureSuggestsExplore() {
        let v = Triage.evaluate(["a": .no, "b": .no, "c": .no, "d": .unsure, "e": .unsure, "f": .unsure, "g": .unsure])
        XCTAssertTrue(v.flagged)
        XCTAssertEqual(v.suggestion, .exploreFurther)
    }

    func testUnsureAloneNeverFlags() {
        let v = Triage.evaluate(Dictionary(uniqueKeysWithValues: OpportunityFilterQuestions.keys.map { ($0, TriageAnswer.unsure) }))
        XCTAssertFalse(v.flagged)
        XCTAssertEqual(v.answered, 10)
    }
}
