import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Decision 0037: desk research is graded by its sources; lived evidence
/// outranks it and is shown as a move.
@MainActor
final class ProofTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    private func prefill(_ idea: Idea, citing url: String) {
        let page = Source(kind: .web, title: "page", fullText: "$149/mo", sourceClass: .aiFound, url: url)
        idea.sources.append(page)
        let criteria = Lenses.business.criteria.map {
            PrefillResult.CriterionDraft(key: $0.key, score: 3, evidenceLevel: 2, note: "desk", sourceIDs: [page.id])
        }
        let r = PrefillResult(
            realityCheck: .init(verdict: .cantTell, summary: "s", competitors: [], demandSignals: [], gapMap: "", fitNotes: "", experiment: nil, costEstimate: ""),
            explorations: [], criteria: criteria, projection: nil,
            riskiestAssumption: .init(belief: "b", consequence: "c", sourceIDs: []),
            nextMove: .init(recommendation: .testRiskiestAssumption, step: "Talk to five owners", experiment: nil),
            draftedAssets: .init(kind: .interviewQuestions, title: "Q", body: "1. When?"),
            panel: [], crossfire: [])
        PrefillApplier.apply(r, rationale: "", costUSD: nil, to: idea, in: store.context)
    }

    func testTwoIdeasWithDifferentSourceQualityGetDifferentDeskScores() throws {
        let forum = Idea(originalText: "Weekend website care for RV parks along one corridor")
        let reviews = Idea(originalText: "Weekend website care for marinas along the Gulf coast")
        store.context.insert(forum)
        store.context.insert(reviews)
        prefill(forum, citing: "https://www.reddit.com/r/RVLiving/comments/1")
        prefill(reviews, citing: "https://www.g2.com/products/marina-software/reviews")

        let f = try XCTUnwrap(forum.latestEvaluation), r = try XCTUnwrap(reviews.latestEvaluation)
        XCTAssertEqual(f.criterionScore(for: "A2")?.deskLevel, 1.2, "one forum post")
        XCTAssertEqual(r.criterionScore(for: "A2")?.deskLevel ?? 0, 1.4, accuracy: 0.001, "one reviewed source")
        XCTAssertNotEqual(f.confidence, r.confidence, "different source quality, different numbers")
        XCTAssertEqual(ProofStage.of(forum), .deskOnly)
    }

    func testLoggingAConversationRaisesProofOnTheStepsCriterion() throws {
        let idea = Idea(originalText: "Clinic-issued ID tags handed to parents at intake")
        store.context.insert(idea)
        prefill(idea, citing: "https://www.reddit.com/r/autism/comments/2")
        let e = try XCTUnwrap(idea.latestEvaluation)
        let before = e.confidence
        let project = WorkshopActions.convert(idea, with: .init(name: "Tags", desiredOutcome: "", nextStep: "Talk to three clinic directors"), in: store.context)
        WorkshopActions.setNextStep(project, "Talk to three clinic directors", target: 3, criterionKey: "A2")

        WorkshopActions.logConversation(project, whatHappened: "Dale at Shady Oaks walked me through their intake and gave me twenty minutes.", from: "Dale", in: store.context)

        let a2 = try XCTUnwrap(e.criterionScore(for: "A2"))
        XCTAssertEqual(a2.evidenceLevel, 3)
        XCTAssertEqual(a2.effectiveLevel, 3, "lived evidence outranks the desk score")
        XCTAssertGreaterThan(e.confidence, before)
        let move = try XCTUnwrap(idea.proofMoves.last)
        XCTAssertEqual(move.from, "Dale")
        XCTAssertEqual(move.delta, e.confidence - before)
        XCTAssertTrue(move.line.hasPrefix("+"))
        XCTAssertEqual(ProofStage.of(idea), .talked(1))
        XCTAssertTrue(ProofStage.of(idea).showsNumber)
    }

    func testProofTileNamesTheNextStep() throws {
        let idea = Idea(originalText: "Clinic-issued ID tags handed to parents at intake")
        store.context.insert(idea)
        prefill(idea, citing: "https://www.reddit.com/r/autism/comments/3")
        XCTAssertEqual(ProofStage.of(idea).nextStep(for: idea), "talk to 3 people who'd buy it")
        XCTAssertEqual(ProofStage.talked(3).nextStep(for: idea), "ask one of them to pay")

        let project = WorkshopActions.convert(idea, with: .init(name: "Tags", desiredOutcome: "", nextStep: "Call Shady Oaks"), in: store.context)
        WorkshopActions.setNextStep(project, "Call Shady Oaks", target: 1, criterionKey: "A2")
        XCTAssertEqual(ProofStage.of(idea).nextStep(for: idea), "Call Shady Oaks", "the idea's own step wins")
        XCTAssertEqual(ProofStage.sentence("talk to 3 people"), "Talk to 3 people.")
    }
}
