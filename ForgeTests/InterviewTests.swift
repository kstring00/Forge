import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Decision 0030: the drafted questions are fillable; Done is one logged conversation.
@MainActor
final class InterviewTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    func testQuestionsParseFromTheDraftedAsset() {
        let body = "Five Mom Test questions\n\n1. When did you last change your website?\n2) What did that cost you?\n- Who else was involved?\nSome note that is not a question.\nWhat would change if it vanished?"
        XCTAssertEqual(InterviewQuestions.parse(body), [
            "When did you last change your website?", "What did that cost you?", "Who else was involved?", "What would change if it vanished?",
        ])
        XCTAssertEqual(InterviewQuestions.parse("no questions here"), InterviewQuestions.fallback)
        XCTAssertTrue(InterviewQuestions.plainText(["A?", "B?"], title: "Step").hasPrefix("Step\n\n1. A?\n2. B?"))
    }

    func testTranscriptAndHeadline() {
        var i = Interview(who: "Maria", whoIs: "runs a daycare", questions: ["When did it last happen?", "What did it cost?"])
        i.answers[0].answer = "Last Tuesday."
        XCTAssertEqual(i.headline, "Maria · runs a daycare")
        XCTAssertEqual(i.answeredCount, 1)
        XCTAssertEqual(i.transcript, "Interview with Maria · runs a daycare\n\nQ: When did it last happen?\nA: Last Tuesday.")
    }

    func testDoneIsOneLoggedConversation() throws {
        let idea = Idea(originalText: "Weekend site care for RV parks along one corridor")
        idea.lensType = .business
        store.context.insert(idea)
        let e = idea.startEvaluation(lensType: .business)
        try e.set(key: "A2", score: 1, evidenceLevel: 0)
        let project = WorkshopActions.convert(idea, with: .init(name: "RV sites", desiredOutcome: "", nextStep: "Talk to five park owners"), in: store.context)
        WorkshopActions.setNextStep(project, "Talk to five park owners", target: 5, criterionKey: "A2")

        var draft = WorkshopActions.currentDraft(for: project)
        XCTAssertEqual(draft.answers.count, InterviewQuestions.fallback.count, "no asset: the fallback questions")
        draft.who = "Dale"
        draft.whoIs = "owns Shady Oaks"
        draft.answers[0].answer = "He paid a nephew $200 last month and showed me the invoice."
        WorkshopActions.saveDraft(draft, on: project)
        XCTAssertEqual(project.interviews.count, 1)
        XCTAssertTrue(project.interviews[0].isDraft)

        let decision = WorkshopActions.finishInterview(draft, rung: 4, on: project, in: store.context)
        XCTAssertNotNil(decision)
        XCTAssertEqual(project.nextStepCount, 1, "the step count advances")
        let done = try XCTUnwrap(project.interviews.first)
        XCTAssertEqual(done.status, .done)
        XCTAssertEqual(done.rung, 4)
        let source = try XCTUnwrap(idea.sources.first { $0.sourceClass == .userVerified })
        XCTAssertTrue(source.fullText.contains("Q: ") && source.fullText.contains("Dale"), "the whole Q&A is the verified source")
        XCTAssertEqual(done.sourceID, source.id)
        XCTAssertEqual(e.criterionScore(for: "A2")?.evidenceLevel, 4, "the rung moved on A2")
        XCTAssertFalse(WorkshopActions.currentDraft(for: project).hasContent, "the next draft starts blank")
    }

    func testEmptyDraftsAreNotKept() {
        let project = Project(name: "P")
        store.context.insert(project)
        let blank = WorkshopActions.currentDraft(for: project)
        WorkshopActions.saveDraft(blank, on: project)
        XCTAssertTrue(project.interviews.isEmpty)
    }
}
