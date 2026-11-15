import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// §6C step 4: every ruling lands in the Journal; Agree never moves a score;
/// Disagree is the user's belief on record; Find out is an Experiment card.
@MainActor
final class RulingActionsTests: XCTestCase {
    private var store: TestStore!
    private var idea: Idea!
    private var page: Source!

    override func setUp() async throws {
        store = try TestStore()
        idea = Idea(originalText: "A website retainer for Texas RV parks")
        store.context.insert(idea)
        page = Source(kind: .web, title: "Northline pricing", fullText: "$149/mo", sourceClass: .aiFound, url: "https://example.com/pricing")
        idea.sources.append(page)
        let e = idea.beginEvaluation(lens: .business)
        try e.set(key: "A5", score: 3, evidenceLevel: 2)
        try e.set(key: "A2", score: 2, evidenceLevel: 1)
        e.criterionScore(for: "A5")?.aiProposed = true
    }

    private func round(_ verdicts: [Verdict]) -> Round {
        let r = Round(pitchText: idea.originalText)
        r.verdicts.append(contentsOf: verdicts)
        idea.rounds.append(r)
        return r
    }

    func testAgreeWritesAJournalEntryAndAttachesTheCitedSourceWithoutMovingTheScore() throws {
        let v = Verdict(sphere: .investor, kind: .onTrack, criterionKey: "A5", reason: "Retainers beat one-offs.", sources: [page])
        _ = round([v])
        let e = try XCTUnwrap(idea.latestEvaluation)
        let potentialBefore = e.potential
        let confidenceBefore = e.confidence

        let ruling = RulingActions.rule(v, .agree, on: idea, in: store.context)

        XCTAssertEqual(v.ruling?.id, ruling.id)
        let d = try XCTUnwrap(ruling.resultingDecision)
        XCTAssertEqual(d.kind, .ruling)
        XCTAssertTrue(d.decision.contains("Investor"))
        XCTAssertTrue(d.decision.contains("A5"))
        XCTAssertEqual(d.idea?.id, idea.id)
        XCTAssertTrue(idea.decisions.contains { $0.id == d.id })

        let ev = try XCTUnwrap(ruling.resultingEvidence)
        XCTAssertEqual(ev.source?.id, page.id)
        XCTAssertEqual(ev.ladderRung, 2, "a desk find is capped at the desk ceiling")
        XCTAssertEqual(e.criterionScore(for: "A5")?.evidence.count, 1)
        XCTAssertEqual(e.criterionScore(for: "A5")?.score, 3)
        XCTAssertEqual(e.criterionScore(for: "A5")?.evidenceLevel, 2)
        XCTAssertEqual(e.criterionScore(for: "A5")?.aiProposed, true, "a ruling never counts as the user picking an anchor")
        e.recompute()
        XCTAssertEqual(e.potential, potentialBefore)
        XCTAssertEqual(e.confidence, confidenceBefore)
        XCTAssertNil(ruling.resultingAssumption)
        XCTAssertNil(ruling.resultingExperiment)
    }

    func testAgreeWithNoSourceAttachesNothing() {
        let v = Verdict(sphere: .customer, kind: .cantTell, criterionKey: "A2", reason: "Nobody has talked to me.", evidenceNeeded: "Five interviews")
        _ = round([v])
        let ruling = RulingActions.rule(v, .agree, on: idea, in: store.context)
        XCTAssertNil(ruling.resultingEvidence)
        XCTAssertNotNil(ruling.resultingDecision)
        XCTAssertEqual(idea.latestEvaluation?.criterionScore(for: "A2")?.evidence.count, 0)
    }

    func testDisagreeRecordsAnAssumptionInTheUsersWords() throws {
        let v = Verdict(sphere: .strategist, kind: .offTrack, criterionKey: "A3", reason: "Same as the alternatives.", sources: [page])
        _ = round([v])
        let ruling = RulingActions.rule(v, .disagree, on: idea, in: store.context, note: "I'd visit in person; nobody else does.")
        let s = try XCTUnwrap(ruling.resultingAssumption)
        XCTAssertEqual(s.sourceClass, .assumption)
        XCTAssertEqual(s.fullText, "I'd visit in person; nobody else does.")
        XCTAssertTrue(idea.sources.contains { $0.id == s.id })
        XCTAssertEqual(ruling.resultingDecision?.beliefs, "I'd visit in person; nobody else does.")
        XCTAssertNil(ruling.resultingEvidence, "disagreeing never attaches the Sphere's source")

        RulingActions.setNote("Actually: I visit every park on the corridor monthly.", on: ruling)
        XCTAssertEqual(s.fullText, "Actually: I visit every park on the corridor monthly.")
        XCTAssertEqual(s.chunks.first?.text, s.fullText)
        XCTAssertEqual(ruling.resultingDecision?.beliefs, s.fullText)
    }

    func testFindOutMakesAnExperimentFromThePlaybookAndDatesTheJournalEntry() throws {
        let v = Verdict(sphere: .customer, kind: .cantTell, criterionKey: "A2", reason: "Nobody has talked to me.", evidenceNeeded: "Five interviews about past behaviour")
        _ = round([v])
        let project = WorkshopActions.convert(idea, with: .init(name: "P", desiredOutcome: "", nextStep: "call"), in: store.context)
        let now = Date(timeIntervalSince1970: 1_700_000_000)

        let ruling = RulingActions.rule(v, .findOut, on: idea, in: store.context, now: now)
        let x = try XCTUnwrap(ruling.resultingExperiment)
        XCTAssertTrue(x.hypothesis.contains("Five interviews"))
        XCTAssertFalse(x.test.isEmpty)
        XCTAssertTrue(x.metric.contains("proof level 2"), "A2 sits at proof level 1, so the card aims one level up: \(x.metric)")
        XCTAssertEqual(x.timeboxDays, 7)
        let d = try XCTUnwrap(ruling.resultingDecision)
        XCTAssertEqual(d.expectedBy, Calendar.current.date(byAdding: .day, value: 7, to: now))
        XCTAssertEqual(d.expectedResult, x.decisionRule)
        XCTAssertTrue(project.notes.contains { $0.hasPrefix("To find out") })
    }

    func testRulingAgainReplacesTheFirstAndItsRecords() throws {
        let v = Verdict(sphere: .investor, kind: .onTrack, criterionKey: "A5", reason: "r", sources: [page])
        _ = round([v])
        let first = RulingActions.rule(v, .agree, on: idea, in: store.context)
        let firstDecision = try XCTUnwrap(first.resultingDecision)
        XCTAssertEqual(idea.latestEvaluation?.criterionScore(for: "A5")?.evidence.count, 1)

        let second = RulingActions.rule(v, .disagree, on: idea, in: store.context)
        try store.context.save()
        XCTAssertEqual(v.ruling?.id, second.id)
        XCTAssertEqual(idea.decisions.filter { $0.kind == .ruling }.count, 1)
        XCTAssertFalse(idea.decisions.contains { $0.id == firstDecision.id })
        XCTAssertEqual(idea.latestEvaluation?.criterionScore(for: "A5")?.evidence.count, 0, "the agree's evidence goes with it")
        XCTAssertNotNil(second.resultingAssumption)
    }

    func testCeilingsBySourceClass() {
        XCTAssertEqual(RulingActions.ceiling(for: Source(kind: .web, title: "", fullText: "", sourceClass: .aiFound)), 2)
        XCTAssertEqual(RulingActions.ceiling(for: Source(kind: .note, title: "", fullText: "", sourceClass: .assumption)), 0)
        XCTAssertEqual(RulingActions.ceiling(for: Source(kind: .voice, title: "", fullText: "", sourceClass: .userVerified)), 5)
    }

    // MARK: Agree is the default; outcomes close the loop

    func testMovingOnSettlesUntouchedVerdictsAsImplicitAgreesWithNoJournalEntry() throws {
        let a = Verdict(sphere: .investor, kind: .onTrack, criterionKey: "A5", reason: "r", sources: [page])
        let b = Verdict(sphere: .strategist, kind: .offTrack, criterionKey: "A3", reason: "r", sources: [page])
        let round = round([a, b])
        RulingActions.rule(b, .disagree, on: idea, in: store.context)
        let journalBefore = idea.decisions.count
        XCTAssertEqual(RulingActions.settleUnruled(round, in: store.context), 1)
        XCTAssertEqual(a.ruling?.choice, .agree)
        XCTAssertEqual(a.ruling?.implicit, true)
        XCTAssertNil(a.ruling?.resultingDecision)
        XCTAssertNil(a.ruling?.resultingEvidence, "an implicit agree attaches nothing")
        XCTAssertEqual(idea.decisions.count, journalBefore)
        XCTAssertEqual(RulingActions.settleUnruled(round, in: store.context), 0)
        let tally = RoundTally(round.verdicts.map { ($0.sphere, $0.kind, $0.ruling?.choice) })
        XCTAssertTrue(tally.isComplete)
        XCTAssertEqual(tally.rulingsLine, "1 disagreement")
    }

    func testOutcomesAreStoredOnceAndReadBackAsOneLine() throws {
        let v = Verdict(sphere: .strategist, kind: .offTrack, criterionKey: "A3", reason: "r", sources: [page])
        _ = round([v])
        let ruling = RulingActions.rule(v, .disagree, on: idea, in: store.context)
        XCTAssertEqual(RulingActions.unsettled(on: idea).map(\.id), [ruling.id])
        RulingActions.recordOutcome(.sphereRight, note: "Nobody switched.", on: ruling)
        XCTAssertEqual(ruling.outcome, .sphereRight)
        XCTAssertEqual(RulingActions.outcomeLine(ruling), "You disagreed with the Strategist. It was right.")
        RulingActions.recordOutcome(.userRight, on: ruling)
        XCTAssertEqual(ruling.outcome, .sphereRight, "the first outcome stands")
        XCTAssertTrue(RulingActions.unsettled(on: idea).isEmpty)

        let settled = RulingActions.settled(in: [idea])
        XCTAssertEqual(settled.count, 1)
        XCTAssertEqual(settled.first?.sphere, .strategist)
        XCTAssertEqual(settled.first?.choice, .disagree)
        XCTAssertEqual(settled.first?.outcome, .sphereRight)
        XCTAssertNil(settled.first?.userScore, "A3 was never scored on this evaluation")
    }
}
