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
}
