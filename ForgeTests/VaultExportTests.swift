import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Brief §11 Phase 1b: an export can be re-imported into a fresh install.
/// Builds a graph touching every model, exports it, imports it into a fresh
/// in-memory store, and checks the graph came back whole. Then imports it
/// again and checks nothing duplicated.
@MainActor
final class VaultExportTests: XCTestCase {

    private struct Fixture {
        var ideaID: UUID
        var pivotID: UUID
        var sourceID: UUID
        var decisionID: UUID
        var projectDecisionID: UUID
        var pitchID: UUID
        var originalText: String
        var potential: Int
        var confidence: Int
    }

    private func buildFixture(in context: ModelContext) throws -> Fixture {
        let original = "  Original text with   odd spacing\nand a second line "
        let a = Idea(originalText: original)
        a.title = "Marina booking"
        a.lensType = .business
        a.stage = .evaluate
        a.tags = ["marina", "Email"]
        a.notes = "some notes"
        context.insert(a)

        let src = Source(kind: .web, title: "Dockwa pricing", fullText: "$99 per month", sourceClass: .aiFound, url: "https://example.com/pricing")
        src.reviewed = true
        src.chunks.append(SourceChunk(index: 0, text: "$99 per month"))
        a.sources.append(src)

        let e = a.beginEvaluation(lens: .business)
        for c in Lenses.business.criteria { try e.set(key: c.key, score: 3, evidenceLevel: 2) }
        e.riskiestAssumption = "Small marinas will pay"
        e.recommendation = .testRiskiestAssumption
        e.projectionPricePerUnit = 149
        e.projectionUnitsYearOne = 12
        e.criterionScore(for: "A2")?.evidence.append(Evidence(criterionKey: "A2", ladderRung: 2, text: "They pay for a workaround", source: src))
        e.experiment = Experiment(hypothesis: "h", test: "t", metric: "m", cost: "c", timeboxDays: 7, decisionRule: "d")
        try e.finalize()

        let triage = OpportunityFilter()
        triage.answer("advantage", .yes)
        triage.answer("reach", .no)
        a.triage = triage
        a.explorations.append(Exploration(promptKey: "problem", userText: "Double bookings"))
        a.artifacts.append(LibraryArtifact(kind: .brief, content: "brief text"))

        let d = Decision(kind: .commit, decision: "Try the seasonal wedge", beliefs: "b", reasoning: "r", expectedResult: "one pilot")
        a.decisions.append(d)

        let round = Round(pitchText: "A booking tool for small marinas")
        a.rounds.append(round)
        let v = Verdict(sphere: .customer, kind: .onTrack, criterionKey: "A2", reason: "One paid workaround.", sources: [src])
        round.verdicts.append(v)
        let ruling = Ruling(choice: .agree)
        v.ruling = ruling
        ruling.resultingDecision = d
        round.crossfire.append(Crossfire(from: .skeptic, to: .customer, text: "One is an anecdote."))

        let rc = RealityCheck(verdict: .compete, summary: "Crowded but a wedge exists.", costEstimate: "$0.40")
        rc.competitors.append(Competitor(name: "Dockwa", pricing: "$99/mo", positioning: "Reservations", complaints: ["slow onboarding"], source: src))
        rc.sources = [src]
        rc.demandSignals = [DemandSignal(text: "complaints", rung: 2)]
        a.realityChecks.append(rc)

        let p = Project(name: "Marina pilot", desiredOutcome: "One paid pilot")
        p.nextStep = "Call Harbor View"
        let m = Milestone(title: "First call", order: 0)
        m.tasks.append(ProjectTask(title: "Find the number"))
        p.milestones.append(m)
        a.project = p
        let pd = Decision(kind: .outcome, decision: "Project-only decision")
        context.insert(pd)
        pd.project = p

        let b = Idea(originalText: "Same tool, sold through marina associations", origin: .pivoted)
        b.title = "Channel pivot"
        b.pivotType = .channel
        b.pivotOf = a
        context.insert(b)

        let pitch = Pitch(title: "P", body: "body", forWhom: "w", whyNow: "n", advantageUsed: "a", riskiestAssumption: "r", cluster: .recurring)
        pitch.status = .saved
        pitch.savedIdea = b
        context.insert(pitch)
        context.insert(Advantage(text: "Swift", kind: .skill))
        context.insert(Constraint(text: "no service businesses", fromPitch: pitch))
        context.insert(StewardCharter(text: "Family first."))
        try context.save()

        return Fixture(ideaID: a.id, pivotID: b.id, sourceID: src.id, decisionID: d.id, projectDecisionID: pd.id,
                       pitchID: pitch.id, originalText: original, potential: e.potential, confidence: e.confidence)
    }

    func testExportImportRoundTripIntoFreshStore() throws {
        let source = try ModelContainer.forge(inMemory: true).mainContext
        let fx = try buildFixture(in: source)

        let doc = try VaultExporter.document(from: source)
        let data = try VaultExporter.encode(doc)
        let decoded = try VaultExporter.decode(data)
        XCTAssertEqual(decoded.schemaVersion, VaultExportDocument.currentSchemaVersion)
        XCTAssertEqual(decoded.ideas.count, 2)
        XCTAssertEqual(decoded.decisions.count, 2)

        let fresh = try ModelContainer.forge(inMemory: true).mainContext
        let summary = try VaultImporter.importDocument(decoded, into: fresh)
        XCTAssertEqual(summary.ideasImported, 2)
        XCTAssertEqual(summary.ideasSkipped, 0)
        XCTAssertEqual(summary.decisionsImported, 2)
        XCTAssertEqual(summary.pitchesImported, 1)
        XCTAssertEqual(summary.advantagesImported, 1)
        XCTAssertEqual(summary.constraintsImported, 1)
        XCTAssertTrue(summary.charterImported)

        let ideas = try fresh.fetch(FetchDescriptor<Idea>())
        XCTAssertEqual(ideas.count, 2)
        let a = try XCTUnwrap(ideas.first { $0.id == fx.ideaID })
        let b = try XCTUnwrap(ideas.first { $0.id == fx.pivotID })

        XCTAssertEqual(a.originalText, fx.originalText, "original text must survive byte for byte")
        XCTAssertEqual(a.title, "Marina booking")
        XCTAssertEqual(a.tags, ["marina", "Email"])
        XCTAssertEqual(a.notes, "some notes")
        XCTAssertEqual(a.stage, .evaluate)
        XCTAssertEqual(a.lensType, .business)
        XCTAssertEqual(a.triage?.answers["reach"], .no)
        XCTAssertEqual(a.explorations.count, 1)
        XCTAssertEqual(a.artifacts.first?.kind, .brief)

        let e = try XCTUnwrap(a.evaluations.first)
        XCTAssertEqual(e.version, 1)
        XCTAssertTrue(e.isFinal)
        XCTAssertEqual(e.potential, fx.potential)
        XCTAssertEqual(e.confidence, fx.confidence)
        XCTAssertEqual(e.criteria.count, 6)
        XCTAssertEqual(e.recommendation, .testRiskiestAssumption)
        XCTAssertEqual(e.projectionPricePerUnit, 149)
        XCTAssertEqual(e.projectionUnitsYearOne, 12)
        XCTAssertNil(e.impactWho)
        XCTAssertEqual(e.experiment?.hypothesis, "h")
        let a2 = try XCTUnwrap(e.criterionScore(for: "A2"))
        XCTAssertEqual(a2.evidence.count, 1)
        XCTAssertEqual(a2.evidence.first?.source?.id, fx.sourceID)
        XCTAssertEqual(a2.evidence.first?.source?.reviewed, true)
        XCTAssertEqual(a.sources.first?.chunks.count, 1)

        let round = try XCTUnwrap(a.rounds.first)
        let verdict = try XCTUnwrap(round.verdicts.first)
        XCTAssertEqual(verdict.kind, .onTrack)
        XCTAssertEqual(verdict.sources.map(\.id), [fx.sourceID])
        XCTAssertEqual(verdict.ruling?.choice, .agree)
        XCTAssertEqual(verdict.ruling?.resultingDecision?.id, fx.decisionID)
        XCTAssertEqual(round.crossfire.count, 1)

        let rc = try XCTUnwrap(a.realityChecks.first)
        XCTAssertEqual(rc.verdict, .compete)
        XCTAssertEqual(rc.competitors.first?.source?.id, fx.sourceID)
        XCTAssertEqual(rc.demandSignals.first?.rung, 2)

        let p = try XCTUnwrap(a.project)
        XCTAssertEqual(p.name, "Marina pilot")
        XCTAssertEqual(p.nextStep, "Call Harbor View")
        XCTAssertEqual(p.milestones.first?.tasks.first?.title, "Find the number")
        let decisions = try fresh.fetch(FetchDescriptor<Decision>())
        XCTAssertEqual(decisions.count, 2)
        XCTAssertEqual(decisions.first { $0.id == fx.projectDecisionID }?.project?.id, p.id)
        XCTAssertEqual(a.decisions.map(\.id), [fx.decisionID])

        XCTAssertEqual(b.pivotOf?.id, fx.ideaID)
        XCTAssertEqual(b.pivotType, .channel)
        XCTAssertEqual(a.pivots.count, 1)

        let pitch = try XCTUnwrap(try fresh.fetch(FetchDescriptor<Pitch>()).first)
        XCTAssertEqual(pitch.savedIdea?.id, fx.pivotID)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Constraint>()).first?.fromPitch?.id, fx.pitchID)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<StewardCharter>()).first?.text, "Family first.")

        // Second import of the same document changes nothing.
        let again = try VaultImporter.importDocument(decoded, into: fresh)
        XCTAssertEqual(again.ideasImported, 0)
        XCTAssertEqual(again.ideasSkipped, 2)
        XCTAssertEqual(again.decisionsImported, 0)
        XCTAssertEqual(again.pitchesImported, 0)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Idea>()).count, 2)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Decision>()).count, 2)
        XCTAssertEqual(try fresh.fetch(FetchDescriptor<Source>()).count, 1)
    }

    func testMarkdownIsReadable() throws {
        let context = try ModelContainer.forge(inMemory: true).mainContext
        let fx = try buildFixture(in: context)
        let md = VaultExporter.markdown(try VaultExporter.document(from: context))
        XCTAssertTrue(md.contains("## Marina booking"))
        XCTAssertTrue(md.contains("## Channel pivot"))
        XCTAssertTrue(md.contains("> " + String(fx.originalText.split(separator: "\n", omittingEmptySubsequences: false)[0])))
        XCTAssertTrue(md.contains("Potential \(fx.potential), Confidence \(fx.confidence)"))
        XCTAssertTrue(md.contains("### Project: Marina pilot"))
        XCTAssertTrue(md.contains("## Steward charter"))
    }

    func testBundleWritesJSONAndMarkdown() throws {
        let context = try ModelContainer.forge(inMemory: true).mainContext
        _ = try buildFixture(in: context)
        let doc = try VaultExporter.document(from: context)
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: parent) }

        let folder = try VaultExporter.writeBundle(doc, to: parent, recordingsFrom: parent)
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("vault.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: folder.appendingPathComponent("vault.md").path))
        let reread = try VaultExporter.decode(Data(contentsOf: folder.appendingPathComponent("vault.json")))
        XCTAssertEqual(reread.ideas.count, 2)
    }

    func testNewerSchemaIsRefused() throws {
        let context = try ModelContainer.forge(inMemory: true).mainContext
        var doc = try VaultExporter.document(from: context)
        doc.schemaVersion = VaultExportDocument.currentSchemaVersion + 1
        XCTAssertThrowsError(try VaultImporter.importDocument(doc, into: context))
    }
}
