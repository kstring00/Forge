import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// The whole V1 schema must open. Catches relationship and inverse mistakes
/// on the first test run rather than the first launch.
@MainActor
final class ModelContainerTests: XCTestCase {
    func testContainerOpensWithEverySchemaModel() throws {
        let store = try TestStore()
        XCTAssertEqual(ForgeSchemaV1.models.count, 24)
        XCTAssertNotNil(store.context)
    }

    func testRoundGraphRoundTrips() throws {
        let store = try TestStore()
        let context = store.context
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

    func testRealityCheckAndJournalRoundTrip() throws {
        let store = try TestStore()
        let context = store.context
        let idea = Idea(originalText: "a booking tool for marinas")
        idea.lensType = .business
        context.insert(idea)

        let pricingPage = Source(kind: .web, title: "Dockwa pricing", fullText: "$99/mo", sourceClass: .aiFound, url: "https://example.com/pricing")
        idea.sources.append(pricingPage)

        let check = RealityCheck(verdict: .compete, summary: "Crowded, but reviews complain about onboarding.", costEstimate: "about $0.40")
        check.demandSignals = [DemandSignal(text: "Harbor masters complain about double bookings", rung: 5, sourceID: pricingPage.id)]
        check.gapMap = "Everyone charges per slip; nobody offers seasonal flat pricing."
        check.competitors.append(Competitor(name: "Dockwa", url: "https://example.com", pricing: "$99/mo", positioning: "Marina reservations", complaints: ["slow onboarding"], source: pricingPage))
        check.sources = [pricingPage]
        idea.realityChecks.append(check)

        let decision = Decision(kind: .commit, decision: "Try the seasonal-pricing wedge with three local marinas",
                                beliefs: "Small marinas resent per-slip pricing", reasoning: "Three complaint threads say so",
                                expectedResult: "One marina agrees to a paid pilot", expectedBy: Date().addingTimeInterval(14 * 86_400))
        idea.decisions.append(decision)
        try context.save()

        XCTAssertEqual(idea.latestRealityCheck?.verdict, .compete)
        XCTAssertEqual(check.demandSignals.first?.rung, Scoring.deskResearchRungCeiling, "desk research is capped at rung 2")
        XCTAssertEqual(check.competitors.first?.realityCheck?.id, check.id)
        XCTAssertEqual(check.limitsNote, RealityCheck.standardLimitsNote)
        XCTAssertEqual(idea.decisions.first?.kind, .commit)
        XCTAssertFalse(decision.hasOutcome)
        decision.recordOutcome("Two said no, one asked for a demo.")
        decision.recordOutcome("overwrite attempt")
        XCTAssertEqual(decision.actualResult, "Two said no, one asked for a demo.", "an outcome is never overwritten")
        XCTAssertEqual(decision.decision, decision.text)
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
