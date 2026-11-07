import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Brief §12: evaluations are append-only. Re-evaluating creates version n+1
/// and never touches version n.
@MainActor
final class EvaluationAppendOnlyTests: XCTestCase {
    private func makeContext() throws -> ModelContext {
        try ModelContainer.forge(inMemory: true).mainContext
    }

    func testReEvaluationAppendsANewVersion() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "an idea")
        context.insert(idea)

        let v1 = idea.beginEvaluation(lens: .business)
        for c in Lenses.business.criteria {
            try v1.set(key: c.key, score: 2, evidenceLevel: 1)
        }
        try v1.finalize()
        try context.save()
        let v1Potential = v1.potential
        let v1Confidence = v1.confidence

        let v2 = idea.beginEvaluation(lens: .business)
        for c in Lenses.business.criteria {
            try v2.set(key: c.key, score: 4, evidenceLevel: 3)
        }
        try v2.finalize()
        try context.save()

        XCTAssertEqual(idea.evaluations.count, 2)
        XCTAssertEqual(v1.version, 1)
        XCTAssertEqual(v2.version, 2)
        XCTAssertEqual(v1.potential, v1Potential)
        XCTAssertEqual(v1.confidence, v1Confidence)
        XCTAssertEqual(v1.potential, 25)
        XCTAssertEqual(v2.potential, 75)
        XCTAssertEqual(idea.latestEvaluation?.version, 2)
    }

    func testFinalVersionRefusesEdits() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "an idea")
        context.insert(idea)
        let v1 = idea.beginEvaluation(lens: .creative)
        try v1.set(key: "C1", score: 3, evidenceLevel: 2)
        try v1.finalize()

        XCTAssertThrowsError(try v1.set(key: "C1", score: 5, evidenceLevel: 5)) { error in
            XCTAssertEqual(error as? EvaluationError, .alreadyFinal)
        }
        XCTAssertThrowsError(try v1.finalize())
        XCTAssertEqual(v1.criterionScore(for: "C1")?.score, 3)
    }

    func testPotentialAndConfidenceStaySeparate() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "an idea")
        context.insert(idea)
        let e = idea.beginEvaluation(lens: .business)
        for c in Lenses.business.criteria {
            try e.set(key: c.key, score: 5, evidenceLevel: 0)
        }
        XCTAssertEqual(e.potential, 100)
        XCTAssertEqual(e.confidence, 0)
        XCTAssertTrue(Scoring.isMostlyEnthusiasm(confidence: e.confidence))
    }

    func testShortfallsAreComputed() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "an idea")
        context.insert(idea)
        let e = idea.beginEvaluation(lens: .business)
        try e.set(key: "A1", score: 4, evidenceLevel: 3)
        try e.set(key: "A2", score: 1, evidenceLevel: 1)
        XCTAssertEqual(e.shortfallTexts.count, 1)
        XCTAssertTrue(e.shortfallTexts[0].hasPrefix("Demand evidence:"))
    }
}
