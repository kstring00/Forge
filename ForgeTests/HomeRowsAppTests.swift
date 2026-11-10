import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Decision 0044: what a Home row says comes from the idea's saved records.
/// The rules for order, the open row and the wording are tested in ForgeCore
/// (`HomeRowsTests`); this checks the reading of the records.
@MainActor
final class HomeRowsAppTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    func testARowsStateFollowsTheIdeaFromCaptureToTheWorld() throws {
        let idea = Idea(originalText: "Web care for RV parks, sold one park at a time")
        store.context.insert(idea)
        XCTAssertEqual(HomeRowState.of(idea), .notChecked)
        XCTAssertEqual(HomeRowState.of(idea, checking: true), .checking)
        XCTAssertEqual(HomeRowState.of(idea, failed: true), .checkFailed)
        XCTAssertEqual(HomeRowState.of(idea, failed: true, offline: true), .offline)
        XCTAssertEqual(HomeNextMoveCard.moveLine(for: idea, state: .notChecked), "Get the panel's take.")

        // The panel has answered.
        idea.realityChecks.append(RealityCheck(verdict: .compete, summary: "crowded"))
        XCTAssertEqual(HomeRowState.of(idea, unseenBrief: true), .takeReady)
        XCTAssertEqual(HomeRowState.of(idea).line, "Waiting on your decision")
        XCTAssertEqual(HomeRowState.of(idea, checking: true), .checking, "a fresh check under way wins")

        // A step with real people.
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "", nextStep: "Talk to five park owners"), in: store.context)
        WorkshopActions.setNextStep(project, "Talk to five park owners", target: 5)
        XCTAssertEqual(HomeRowState.of(idea), .stepInProgress(done: 0, of: 5))
        WorkshopActions.logConversation(project, whatHappened: "Met the owner of Shady Oaks.", in: store.context)
        XCTAssertEqual(HomeRowState.of(idea).line, "Talked to 1 of 5 people")
        XCTAssertEqual(HomeRowState.of(idea).progress, "1 of 5 conversations")
        XCTAssertEqual(HomeNextMoveCard.moveLine(for: idea, state: HomeRowState.of(idea)), "Talk to five park owners.")
        for i in 2...5 { WorkshopActions.logConversation(project, whatHappened: "conversation \(i)", in: store.context) }
        XCTAssertEqual(HomeRowState.of(idea), .stepReached(of: 5))

        project.status = .paused
        XCTAssertEqual(HomeRowState.of(idea), .paused)
        project.status = .done
        XCTAssertEqual(HomeRowState.of(idea), .launched)
    }

    func testAPersonalIdeaIsNeverCalledUnchecked() {
        let hobby = Idea(originalText: "Learn to weld well enough to build a gate")
        hobby.lensType = .growth
        store.context.insert(hobby)
        XCTAssertEqual(HomeRowState.of(hobby), .personal)
        XCTAssertEqual(HomeRowState.of(hobby, failed: true), .personal)
    }

    func testTheOpenRowsDescriptionIsThePersonsOwnWordsWhenTheySayMoreThanTheTitle() {
        let idea = Idea(originalText: "What if there was a weekend website-care service for RV parks along one highway corridor\nMost owners have a Facebook page.")
        XCTAssertFalse(idea.homeDescription.isEmpty)
        XCTAssertFalse(idea.homeDescription.contains("Most owners"), "the first line only")
        let short = Idea(originalText: "Dog walking for seniors")
        XCTAssertEqual(short.title, "Dog walking for seniors")
        XCTAssertEqual(short.homeDescription, "", "nothing to add to the title")
    }

    func testEveryStateWithoutScoresSaysWhatIsMissing() {
        for state in [HomeRowState.notChecked, .checking, .checkFailed, .offline, .personal, .noStep, .stepInProgress(done: 0, of: 5)] {
            XCTAssertFalse(HomeRowDetail.missingLine(state).isEmpty, "\(state)")
        }
    }
}
