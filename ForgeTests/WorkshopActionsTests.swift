import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Phase 2 done-check in code: capture → commit → next step done → outcome recorded, no Lab involved.
@MainActor
final class WorkshopActionsTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    private func makeContext() throws -> ModelContext {
        store.context
    }

    func testConvertCreatesProjectAndCommitEntry() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "A retainer for RV parks")
        context.insert(idea)

        let by = Date().addingTimeInterval(14 * 86_400)
        let project = WorkshopActions.convert(idea, with: .init(
            name: "RV park retainer", desiredOutcome: "One park paying monthly", nextStep: "Call Shady Oaks",
            beliefs: "Parks resent one-off web bills", reasoning: "Three said so", expectedResult: "One yes", expectedBy: by), in: context)
        try context.save()

        XCTAssertEqual(idea.project?.id, project.id)
        XCTAssertEqual(idea.stage, .build)
        XCTAssertEqual(project.nextStep, "Call Shady Oaks")
        XCTAssertEqual(project.status, .active)
        XCTAssertEqual(project.decisions.count, 1)
        let commit = try XCTUnwrap(project.decisions.first)
        XCTAssertEqual(commit.kind, .commit)
        XCTAssertEqual(commit.idea?.id, idea.id)
        XCTAssertEqual(commit.beliefs, "Parks resent one-off web bills")
        XCTAssertEqual(commit.expectedResult, "One yes")
        XCTAssertEqual(commit.expectedBy, by)
        XCTAssertFalse(commit.hasOutcome)
        XCTAssertEqual(idea.originalText, "A retainer for RV parks")
    }

    func testConvertTwiceReturnsTheSameProject() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "x")
        context.insert(idea)
        let a = WorkshopActions.convert(idea, with: .init(name: "A", desiredOutcome: "", nextStep: "one"), in: context)
        let b = WorkshopActions.convert(idea, with: .init(name: "B", desiredOutcome: "", nextStep: "two"), in: context)
        XCTAssertEqual(a.id, b.id)
        XCTAssertEqual(a.name, "A")
        XCTAssertEqual(try context.fetch(FetchDescriptor<Decision>()).count, 1)
    }

    func testCompletingNextStepRecordsOutcomeAndSetsTheNext() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "x")
        context.insert(idea)
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "o", nextStep: "Call the park"), in: context)

        let outcome = WorkshopActions.completeNextStep(project, whatHappened: "Owner asked for a price.", nextStep: "Send a one-page quote", in: context)
        try context.save()

        XCTAssertEqual(outcome?.kind, .outcome)
        XCTAssertEqual(outcome?.decision, "Did: Call the park")
        XCTAssertEqual(outcome?.actualResult, "Owner asked for a price.")
        XCTAssertTrue(outcome?.hasOutcome ?? false)
        XCTAssertEqual(project.nextStep, "Send a one-page quote")
        XCTAssertEqual(project.decisions.count, 2)

        let second = WorkshopActions.completeNextStep(project, whatHappened: "Sent.", nextStep: "   ", in: context)
        XCTAssertNotNil(second)
        XCTAssertNil(project.nextStep, "blank next step leaves it unset")
        XCTAssertNil(WorkshopActions.completeNextStep(project, whatHappened: "nothing to do", nextStep: nil, in: context))
    }

    func testPauseRecordsAgainstTheOpenCommitment() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "x")
        context.insert(idea)
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "o", nextStep: "s", expectedResult: "a yes"), in: context)
        let commit = try XCTUnwrap(WorkshopActions.openCommitment(project))

        WorkshopActions.pause(project, whatHappened: "Season ended; nobody is buying until spring.", in: context)
        XCTAssertEqual(project.status, .paused)
        XCTAssertNotNil(project.pausedAt)
        XCTAssertTrue(commit.hasOutcome)
        XCTAssertTrue(commit.actualResult?.hasPrefix("Paused.") ?? false)
        XCTAssertNil(WorkshopActions.openCommitment(project))

        WorkshopActions.resume(project)
        XCTAssertEqual(project.status, .active)
        XCTAssertNil(project.pausedAt)
    }

    func testLaunchMovesIdeaToLaunchStage() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "x")
        context.insert(idea)
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "o", nextStep: "s"), in: context)
        WorkshopActions.complete(project, whatHappened: "First park paid.", in: context)
        XCTAssertEqual(project.status, .done)
        XCTAssertNotNil(project.completedAt)
        XCTAssertEqual(idea.stage, .launch)
        XCTAssertEqual(project.decisions.filter(\.hasOutcome).count, 1)
    }

    func testStatusChangeWithoutTextWritesNoEntry() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "x")
        context.insert(idea)
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "", nextStep: "s"), in: context)
        WorkshopActions.pause(project, whatHappened: "   ", in: context)
        XCTAssertEqual(project.decisions.count, 1)
        XCTAssertFalse(project.decisions[0].hasOutcome)
    }

    // MARK: v4.2: the next step carries a count, a caveat and a due date

    func testLogConversationAdvancesTheCountAndWritesAnOutcome() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "x")
        context.insert(idea)
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "", nextStep: "placeholder"), in: context)
        let due = Date(timeIntervalSince1970: 1_800_000_000)
        WorkshopActions.setNextStep(project, "Talk to five parents", caveat: "Ask what happened last time.", target: 5, dueAt: due, moves: "Moves Demand to rung 3")
        XCTAssertEqual(project.nextStepTarget, 5)
        XCTAssertEqual(project.nextStepCount, 0)
        XCTAssertEqual(project.nextStepDueAt, due)

        XCTAssertNil(WorkshopActions.logConversation(project, whatHappened: "   ", in: context), "an empty log records nothing")
        let d = try XCTUnwrap(WorkshopActions.logConversation(project, whatHappened: "She uses a paper card.", in: context))
        XCTAssertEqual(project.nextStepCount, 1)
        XCTAssertEqual(d.kind, .outcome)
        XCTAssertTrue(d.decision.hasPrefix("Logged 1 of 5"))
        XCTAssertEqual(d.actualResult, "She uses a paper card.")
        XCTAssertEqual(d.project?.id, project.id)
        XCTAssertEqual(project.nextStep, "Talk to five parents", "logging never closes the step")
        XCTAssertFalse(WorkshopActions.targetReached(project))
        for i in 2...5 { WorkshopActions.logConversation(project, whatHappened: "conversation \(i)", in: context) }
        XCTAssertTrue(WorkshopActions.targetReached(project))

        WorkshopActions.completeNextStep(project, whatHappened: "Five done.", nextStep: "Draft the page", in: context)
        XCTAssertEqual(project.nextStep, "Draft the page")
        XCTAssertEqual(project.nextStepCount, 0)
        XCTAssertEqual(project.nextStepTarget, 1)
        XCTAssertNil(project.nextStepCaveat)
        XCTAssertNil(project.nextStepDueAt)
    }

    func testNextStepPlanReadsTheStepThenTheAsset() {
        XCTAssertEqual(NextStepPlan.target(assetTitle: "Five Mom Test questions", step: "Ask five park owners"), 5)
        XCTAssertEqual(NextStepPlan.target(assetTitle: nil, step: "Talk to five parents of non-verbal autistic kids about what they use now."), 5)
        XCTAssertEqual(NextStepPlan.target(assetTitle: "Five Mom Test questions", step: "Have three conversations with park owners"), 3)
        XCTAssertEqual(NextStepPlan.target(assetTitle: "A twenty-message outreach script", step: "Message owners"), 20)
        XCTAssertEqual(NextStepPlan.target(assetTitle: "Landing page copy", step: "Put the page up"), 1)
        XCTAssertEqual(NextStepPlan.target(assetTitle: nil, step: "Call Shady Oaks"), 1)
        XCTAssertEqual(NextStepPlan.ridingLine(confidence: 33, target: 5, moves: "Moves Demand to rung 3"),
                       "This step is how 33 becomes a real number. Five conversations move demand to rung 3.")
        XCTAssertEqual(NextStepPlan.ridingLine(confidence: 20, target: 1, moves: nil),
                       "This step is how 20 becomes a real number. One conversation and Confidence can move.")
        XCTAssertNil(NextStepPlan.caveat(step: "Ask five owners", experimentTest: "Ask five owners."))
        XCTAssertEqual(NextStepPlan.caveat(step: "Ask five owners", experimentTest: "Ask about the last time it failed. Don't pitch."), "Ask about the last time it failed. Don't pitch.")
    }

    // MARK: §0A step 6: what comes back from the world is verified evidence

    func testLoggingAConversationSavesAVerifiedSourceAndMovesTheLadderPastTheDeskCap() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "A website retainer for Texas RV parks")
        context.insert(idea)
        let e = idea.beginEvaluation(lens: .business)
        try e.set(key: "A2", score: 2, evidenceLevel: 2)
        e.criterionScore(for: "A2")?.aiProposed = true
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "", nextStep: "Talk to five park owners"), in: context)
        WorkshopActions.setNextStep(project, "Talk to five park owners", target: 5, criterionKey: "A2")
        let confidenceBefore = e.confidence

        WorkshopActions.logConversation(project, whatHappened: "Met the owner of Shady Oaks; she showed me her Facebook page and said she pays a nephew.", in: context)
        let score = try XCTUnwrap(e.criterionScore(for: "A2"))
        XCTAssertEqual(score.evidenceLevel, 3, "a conversation is time given: rung 3, past the desk cap of 2")
        XCTAssertEqual(score.peopleAtRung, 1)
        XCTAssertFalse(score.aiProposed)
        XCTAssertEqual(score.evidence.count, 1)
        let source = try XCTUnwrap(score.evidence.first?.source)
        XCTAssertEqual(source.sourceClass, .userVerified)
        XCTAssertTrue(source.reviewed)
        XCTAssertTrue(source.title.hasPrefix("Conversation: "))
        XCTAssertTrue(idea.sources.contains { $0.id == source.id })
        XCTAssertGreaterThan(e.confidence, confidenceBefore)

        // A payment reported: rung 4, one person there; A2's score waits for three.
        WorkshopActions.logConversation(project, whatHappened: "Harbor View paid a $149 deposit for month one.", in: context)
        XCTAssertEqual(score.evidenceLevel, 4)
        XCTAssertEqual(score.peopleAtRung, 1)
        XCTAssertEqual(score.score, 1, "A2's score is the highest rung three people reached")
        XCTAssertEqual(project.nextStepCount, 2)
        XCTAssertEqual(e.projection.verifiedUnits, 1, "a rung-4 verified payment counts toward the projection")
    }

    /// The sheet's "Counts as" menu is the person's call: lowering it sticks.
    func testThePersonsPickDecidesWhatAConversationCountsAs() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "A website retainer for Texas RV parks")
        context.insert(idea)
        let e = idea.beginEvaluation(lens: .business)
        try e.set(key: "A2", score: 2, evidenceLevel: 2)
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "", nextStep: "Talk to five park owners"), in: context)
        WorkshopActions.setNextStep(project, "Talk to five park owners", target: 5, criterionKey: "A2")

        // The words read as a payment; the person says it was only a conversation.
        let words = "He said he paid the last web guy a deposit and got burned."
        XCTAssertEqual(RungInference.rungForConversation(words), 4)
        WorkshopActions.logConversation(project, whatHappened: words, rung: 3, in: context)
        XCTAssertEqual(e.criterionScore(for: "A2")?.evidenceLevel, 3)

        // Raising it works as before.
        WorkshopActions.logConversation(project, whatHappened: "Nice chat, and he handed me a check.", rung: 4, in: context)
        XCTAssertEqual(e.criterionScore(for: "A2")?.evidenceLevel, 4)
    }

    func testFinishingAStepRecordsTheReportAtTheRungTheUserConfirmed() throws {
        let context = try makeContext()
        let idea = Idea(originalText: "x")
        context.insert(idea)
        let e = idea.beginEvaluation(lens: .business)
        try e.set(key: "A2", score: 1, evidenceLevel: 1)
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "", nextStep: "Ask five owners"), in: context)
        WorkshopActions.completeNextStep(project, whatHappened: "Two of five came back for a second call.", nextStep: nil, rung: 5, in: context)
        XCTAssertEqual(e.criterionScore(for: "A2")?.evidenceLevel, 5)
        XCTAssertEqual(idea.sources.filter { $0.sourceClass == .userVerified }.count, 1)
        XCTAssertNil(project.nextStep)

        // Nothing claimed: the words are kept, the ladder does not move.
        let quiet = Idea(originalText: "y")
        context.insert(quiet)
        let qe = quiet.beginEvaluation(lens: .business)
        try qe.set(key: "A2", score: 1, evidenceLevel: 1)
        let r = FieldEvidence.record(.init(text: "Thought about it.", rung: 0), kind: "What happened", on: quiet)
        XCTAssertNil(r.evidence)
        XCTAssertEqual(qe.criterionScore(for: "A2")?.evidenceLevel, 1)
        XCTAssertEqual(quiet.sources.count, 1)
        XCTAssertEqual(FieldEvidence.line(for: r, lens: Lenses.business), "Saved as verified by you.")
    }
}
