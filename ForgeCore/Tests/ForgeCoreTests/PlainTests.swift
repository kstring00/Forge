import XCTest
@testable import ForgeCore

/// Decision 0029: plain words first, the brand term beside them.
final class PlainTests: XCTestCase {
    func testPhrases() {
        XCTAssertEqual(Plain.rung(3), "proof level 3 of 5")
        XCTAssertEqual(Plain.level(4), "Level 4")
        XCTAssertEqual(Plain.beside("Confidence", "How sure we are"), "Confidence · how sure we are")
        for s in [Plain.confidence, Plain.potential, Plain.panel, Plain.step, Plain.ladder, Plain.lens] {
            XCTAssertFalse(s.isEmpty)
            XCTAssertFalse(s.contains("rung") || s.contains("Sphere"), "plain phrases carry no jargon")
        }
    }
}
