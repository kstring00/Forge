import XCTest
import SwiftData
import ForgeCore
@testable import Forge

@MainActor
final class LabModelTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    private func scoredIdea() throws -> (Idea, Evaluation) {
        let idea = Idea(originalText: "A website retainer for Texas RV parks")
        store.context.insert(idea)
        let e = idea.beginEvaluation(lens: .business)
        XCTAssertEqual(idea.lensType, .business, "first evaluation sets the lens")
        XCTAssertEqual(idea.stage, .evaluate)
        for c in Lenses.business.criteria { try e.set(key: c.key, score: 4, evidenceLevel: 1) }
        return (idea, e)
    }

    func testNewVersionCopiesForwardAndLeavesTheOldOneAlone() throws {
        let (idea, v1) = try scoredIdea()
        v1.riskiestAssumption = "Owners will pay monthly"
        v1.nextStepText = "Ask five owners"
        v1.projectionPricePerUnit = 149
        v1.projectionUnitsYearOne = 12
        let src = Source(kind: .note, title: "Interview", fullText: "Owner pays $40/mo for a workaround", sourceClass: .userVerified)
        idea.sources.append(src)
        v1.criterionScore(for: "A1")?.evidence.append(Evidence(criterionKey: "A1", ladderRung: 4, text: "pays for a workaround", source: src))
        try v1.finalize()
        try store.context.save()

        let v2 = idea.beginEvaluation(lens: .business, copying: v1)
        XCTAssertEqual(v2.version, 2)
        XCTAssertFalse(v2.isFinal)
        XCTAssertEqual(v2.criteria.count, 6)
        XCTAssertEqual(v2.criterionScore(for: "A1")?.score, 4)
        XCTAssertEqual(v2.criterionScore(for: "A1")?.evidence.first?.source?.id, src.id)
        XCTAssertEqual(v2.riskiestAssumption, "Owners will pay monthly")
        XCTAssertEqual(v2.projectionUnitsYearOne, 12)
        XCTAssertEqual(v2.potential, v1.potential)

        try v2.set(key: "A2", score: 1, evidenceLevel: 1)
        XCTAssertEqual(v1.criterionScore(for: "A2")?.score, 4, "v1 untouched")
        XCTAssertTrue(v1.isFinal)
        XCTAssertEqual(idea.evaluations.count, 2)
    }

    func testBlankNewVersionStartsEmpty() throws {
        let (idea, v1) = try scoredIdea()
        try v1.finalize()
        let v2 = idea.beginEvaluation(lens: .business)
        XCTAssertEqual(v2.criteria.count, 0)
        XCTAssertEqual(v2.potential, 0)
        XCTAssertFalse(v2.isComplete)
    }

    func testBreakdownPatternAndProjectionFollowEvidence() throws {
        let (idea, e) = try scoredIdea()
        XCTAssertEqual(e.pattern(for: "A2"), .dots, "no evidence reads as assumption")
        XCTAssertEqual(e.confidenceBreakdown.assumptionPercent, 0, "no items at all: all zero")

        let paid = Source(kind: .note, title: "Deposit", fullText: "$149 deposit from Shady Oaks", sourceClass: .userVerified)
        let page = Source(kind: .web, title: "Competitor pricing", fullText: "$99/mo", sourceClass: .aiFound, url: "https://example.com")
        idea.sources.append(paid)
        idea.sources.append(page)
        e.criterionScore(for: "A2")?.evidence.append(Evidence(criterionKey: "A2", ladderRung: 4, text: "deposit paid", source: paid))
        e.criterionScore(for: "A3")?.evidence.append(Evidence(criterionKey: "A3", ladderRung: 2, text: "three competitors", source: page))
        e.criterionScore(for: "A4")?.evidence.append(Evidence(criterionKey: "A4", ladderRung: 1, text: "I think so", source: nil))

        XCTAssertEqual(e.pattern(for: "A2"), .solid)
        XCTAssertEqual(e.pattern(for: "A3"), .stripes)
        XCTAssertEqual(e.pattern(for: "A4"), .dots)
        let b = e.confidenceBreakdown
        XCTAssertEqual(b.verifiedPercent + b.aiFoundPercent + b.assumptionPercent, 100)
        XCTAssertEqual(b.verifiedPercent, 34, "rounding drift lands on the largest bucket")

        e.projectionPricePerUnit = 149
        e.projectionUnitsYearOne = 12
        let p = e.projection
        XCTAssertEqual(p.verifiedUnits, 1, "one rung-4 verified payment")
        XCTAssertEqual(p.assumedUnits, 11)
        XCTAssertEqual(p.recurringPerMonth, 1788)

        page.reviewed = true
        XCTAssertEqual(e.projection.verifiedUnits, 1, "a reviewed competitor page at rung 2 is still not a payment")
    }

    func testLadderKeyAndSuggestedMove() throws {
        let (_, e) = try scoredIdea()
        XCTAssertEqual(e.ladderKey, "A2")
        XCTAssertEqual(e.suggestedMove(triageFlagged: false), .testRiskiestAssumption, "scores of 4 with rung-1 evidence is enthusiasm")
        XCTAssertEqual(e.effectiveMove, .testRiskiestAssumption)
        XCTAssertEqual(e.effectiveStep, "Have five Mom Test conversations", "default step comes from A2's playbook when A2 is lowest or tied")
        e.recommendation = .startBuilding
        e.nextStepText = "Convert it"
        XCTAssertEqual(e.effectiveMove, .startBuilding)
        XCTAssertEqual(e.effectiveStep, "Convert it")
    }

    func testTriageIsStoredAndFlagged() throws {
        let idea = Idea(originalText: "x")
        store.context.insert(idea)
        let t = OpportunityFilter()
        for (i, key) in OpportunityFilterQuestions.keys.enumerated() { t.answer(key, i < 4 ? .no : .yes) }
        idea.triage = t
        XCTAssertTrue(t.isComplete)
        XCTAssertTrue(t.verdict.flagged)
        XCTAssertEqual(t.verdict.suggestion, .revisitLater)
        let e = idea.beginEvaluation(lens: .business)
        for c in Lenses.business.criteria { try e.set(key: c.key, score: 5, evidenceLevel: 0) }
        XCTAssertEqual(e.effectiveMove, .revisitLater, "flagged triage plus no evidence")
    }
}
