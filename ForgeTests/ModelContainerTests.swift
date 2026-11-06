import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// The whole V1 schema must open. Catches relationship and inverse mistakes
/// on the first test run rather than the first launch.
@MainActor
final class ModelContainerTests: XCTestCase {
    func testContainerOpensWithEverySchemaModel() throws {
        let container = try ModelContainer.forge(inMemory: true)
        XCTAssertEqual(ForgeSchemaV1.models.count, 22)
        XCTAssertNotNil(container.mainContext)
    }

    func testRoundGraphRoundTrips() throws {
        let context = try ModelContainer.forge(inMemory: true).mainContext
        let idea = Idea(originalText: "pitch me")
        context.insert(idea)
        let source = Source(kind: .note, title: "Interview 1", fullText: "They pay $40/mo for a workaround.", sourceClass: .userVerified)
        idea.sources.append(source)

        let round = Round(pitchText: "A tool for X")
        idea.rounds.append(round)
        let cited = Verdict(sphere: .customer, kind: .onTrack, criterionKey: "A2", reason: "One paid workaround observed.", sources: [source])
        let uncited = Verdict(sphere: .investor, kind: .onTrack, criterionKey: "A5", reason: "No channel named.", evidenceNeeded: "Twenty outreaches with replies recorded.")
        round.verdicts.append(cited)
        round.verdicts.append(uncited)
        round.crossfire.append(Crossfire(from: .skeptic, to: .customer, text: "One person is an anecdote."))
        let ruling = Ruling(choice: .findOut)
        uncited.ruling = ruling
        ruling.resultingExperiment = Experiment(hypothesis: "h", test: "t", metric: "m", cost: "c", timeboxDays: 7, decisionRule: "d")
        try context.save()

        XCTAssertEqual(cited.kind, .onTrack)
        XCTAssertEqual(uncited.kind, .cantTell, "a verdict with no sources must be cantTell")
        XCTAssertEqual(round.rulings.count, 1)
        XCTAssertFalse(round.isRuled)
        XCTAssertEqual(idea.rounds.first?.verdicts.count, 2)
        XCTAssertEqual(ruling.resultingExperiment?.ruling?.id, ruling.id)
    }

    func testStewardCharterShipsAsPlaceholder() {
        let charter = StewardCharter()
        XCTAssertTrue(charter.isPlaceholder)
        XCTAssertEqual(charter.displayText, Spheres.charterPlaceholder)
    }

    func testOfflineClientReportsOffline() async {
        let client = OfflineAIClient()
        XCTAssertFalse(client.isAvailable)
        let ctx = AIContext(ideaID: UUID(), originalText: "x", title: "x")
        do {
            _ = try await client.perform(.expand, context: ctx, expecting: ExpandResult.self)
            XCTFail("expected offline error")
        } catch {
            XCTAssertEqual(error as? AIError, .offline)
        }
    }
}
