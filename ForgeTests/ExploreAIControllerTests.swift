import XCTest
import SwiftData
import ForgeCore
@testable import Forge

@MainActor
final class ExploreAIControllerTests: XCTestCase {
    private func makeIdea() throws -> Idea {
        let context = try ModelContainer.forge(inMemory: true).mainContext
        let idea = Idea(originalText: "retainer for rv parks, cheap site + monthly fee")
        context.insert(idea)
        ExploreActions.answer("Parks have a Facebook page and nothing else", promptKey: "today", on: idea)
        return idea
    }

    func testOfflineClientYieldsCalmOfflineState() async throws {
        let idea = try makeIdea()
        let controller = ExploreAIController(client: OfflineAIClient())
        await controller.expand(idea)
        XCTAssertEqual(controller.state, .offline(ExploreAIController.offlineMessage))
        XCTAssertTrue(idea.explorations.filter { ExplorePrompts.isAIKey($0.promptKey) }.isEmpty, "nothing written")
        controller.dismissMessage()
        XCTAssertEqual(controller.state, .idle)
    }

    func testExpandProposesAndAcceptWritesConfirmedNotes() async throws {
        let idea = try makeIdea()
        let result = ExpandResult(proposedTitle: "RV park retainer", proposedSummary: "Monthly web upkeep for RV parks",
                                  clarifiedText: "A low-cost website plus a monthly retainer for independent RV parks along one corridor.",
                                  openQuestions: ["How many parks are on the corridor?", "What do they pay today?"])
        let client = CannedAIClient(responses: [.expand: try CannedAIClient.canned(result, rationale: "Assumption: parks value upkeep.")])
        let controller = ExploreAIController(client: client)

        await controller.expand(idea)
        guard case .proposal(let proposal) = controller.state else { return XCTFail("expected a proposal, got \(controller.state)") }
        XCTAssertEqual(proposal.kind, .expand)
        XCTAssertEqual(proposal.sections.map(\.key), ["ai.expand", "ai.openQuestions", "ai.summary"])
        XCTAssertTrue(idea.explorations.filter { ExplorePrompts.isAIKey($0.promptKey) }.isEmpty, "nothing written before accept")

        let saved = controller.accept(into: idea)
        XCTAssertEqual(saved.count, 3)
        XCTAssertTrue(saved.allSatisfy(\.confirmed))
        XCTAssertEqual(ExploreActions.aiNotes(on: idea).count, 3)
        XCTAssertEqual(controller.state, .idle)
        XCTAssertEqual(idea.originalText, "retainer for rv parks, cheap site + monthly fee")
    }

    func testDiscardWritesNothing() async throws {
        let idea = try makeIdea()
        let result = SummarizeResult(notes: ["One park type"], decisions: [], openQuestions: ["Price?"])
        let client = CannedAIClient(responses: [.summarize: try CannedAIClient.canned(result, rationale: "")])
        let controller = ExploreAIController(client: client)
        await controller.summarize(idea)
        guard case .proposal(let p) = controller.state else { return XCTFail("expected a proposal") }
        XCTAssertEqual(p.sections.map(\.key), ["ai.summary.notes", "ai.summary.openQuestions"])
        controller.discard()
        XCTAssertEqual(controller.state, .idle)
        XCTAssertTrue(ExploreActions.aiNotes(on: idea).isEmpty)
    }

    func testMalformedResponseIsAFailureNotACrash() async throws {
        let idea = try makeIdea()
        let client = CannedAIClient(responses: [.expand: Data("not json".utf8)])
        let controller = ExploreAIController(client: client)
        await controller.expand(idea)
        if case .failed = controller.state {} else { XCTFail("expected failed, got \(controller.state)") }
    }
}
