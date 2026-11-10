import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// §0A: everything the Spheres write is AI-found and stays honest until the
/// user touches it. The applier is the one place that writes a prefill.
@MainActor
final class PrefillApplierTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    private func canned(sourceID: UUID, rung: Int = 2) -> PrefillResult {
        let rc = RealityCheckResult(
            verdict: .compete, summary: "Crowded, but every competitor sells one-off builds.",
            competitors: [.init(name: "Northline", url: "https://example.com/pricing", pricing: "$149/mo", positioning: "Web care for small businesses",
                                praises: ["fast"], complaints: ["slow onboarding"], tractionSignals: ["hiring"], sourceID: sourceID)],
            demandSignals: [.init(text: "Owners complain about stale sites", url: nil, rung: rung, sourceID: sourceID)],
            gapMap: "Nobody offers in-person corridor service.", fitNotes: "Uses existing client work.",
            experiment: .init(hypothesis: "Owners pay monthly", test: "Ask five", metric: "One yes", cost: "$0", timeboxDays: 7, decisionRule: "One yes → build"),
            costEstimate: "about $0.40")
        return PrefillResult(
            realityCheck: rc,
            explorations: [.init(promptKey: "problem", answer: "Parks have a Facebook page and nothing else.", sourceIDs: [sourceID]),
                           .init(promptKey: "who", answer: "Independent RV parks on one corridor.", sourceIDs: [])],
            criteria: Lenses.business.criteria.map { c in
                .init(key: c.key, score: c.key == "A2" ? 2 : 4, evidenceLevel: c.key == "A6" ? 1 : rung, note: "From the desk", sourceIDs: c.key == "A6" ? [] : [sourceID])
            },
            projection: .init(pricePerUnitLow: 99, pricePerUnitHigh: 199, unitsYearOneLow: 8, unitsYearOneHigh: 15, rationale: "Competitor pricing."),
            projectionLow: 900, projectionHigh: 2400, projectionBasis: "three competitors' pricing pages",
            riskiestAssumption: .init(belief: "Owners will pay monthly for a site they don't check.", consequence: "Becomes one-off builds.", sourceIDs: []),
            nextMove: .init(recommendation: .testRiskiestAssumption, step: "Ask five park owners how they handle their website today", experiment: rc.experiment),
            draftedAssets: .init(kind: .interviewQuestions, title: "Five Mom Test questions", body: "1. When did you last change your website?"),
            panel: [.init(sphere: .customer, verdict: .cantTell, criterionKey: "A2", reason: "Nobody has talked to me.", sourceIDs: [], evidenceNeeded: "Five interviews"),
                    .init(sphere: .investor, verdict: .onTrack, criterionKey: "A5", reason: "Retainers beat one-offs.", sourceIDs: [sourceID], evidenceNeeded: nil)],
            crossfire: [.init(from: .skeptic, to: .investor, text: "Every number is an estimate.")])
    }

    func testApplyWritesHonestRecords() throws {
        let idea = Idea(originalText: "A website retainer for Texas RV parks")
        store.context.insert(idea)
        let page = Source(kind: .web, title: "Northline pricing", fullText: "$149/mo", sourceClass: .aiFound, url: "https://example.com/pricing")
        idea.sources.append(page)

        let applied = PrefillApplier.apply(canned(sourceID: page.id), rationale: "What the desk supports…", costUSD: 0.42, to: idea, in: store.context)
        try store.context.save()

        // Reality Check
        XCTAssertEqual(applied.realityCheck.verdict, .compete)
        XCTAssertEqual(applied.realityCheck.competitors.first?.source?.id, page.id)
        XCTAssertEqual(applied.realityCheck.actualCostUSD, 0.42)
        XCTAssertEqual(applied.realityCheck.draftedAssetSourceID, applied.draftedAsset.id)
        XCTAssertEqual(applied.draftedAsset.sourceClass, .aiFound)
        XCTAssertEqual(idea.latestRealityCheck?.id, applied.realityCheck.id)

        // Evaluation: proposed, striped, honest
        let e = applied.evaluation
        XCTAssertEqual(e.version, 1)
        XCTAssertNotNil(e.aiFilledAt)
        XCTAssertTrue(e.isComplete)
        XCTAssertTrue(e.criteria.allSatisfy(\.aiProposed))
        XCTAssertEqual(e.criterionScore(for: "A2")?.score, 2)
        XCTAssertEqual(e.criterionScore(for: "A1")?.evidence.first?.source?.id, page.id)
        // Decision 0037: desk research is graded by its sources. One published page is 1.4
        // (1.0 plus 0.4), not a flat 2; A6 cites nothing and stays at 1.
        XCTAssertEqual(e.criterionScore(for: "A1")?.deskLevel, 1.4)
        XCTAssertEqual(e.criterionScore(for: "A6")?.deskLevel, 1.0)
        XCTAssertEqual(e.confidence, Scoring.confidence(levels: Lenses.business.criteria.map { $0.key == "A6" ? 1.0 : 1.4 }))
        XCTAssertEqual(e.confidence, 27)
        XCTAssertEqual(e.confidenceBreakdown.aiFoundPercent, 100, "every evidence item is an unreviewed AI find")
        XCTAssertTrue(e.allEvidence.allSatisfy { !$0.countsTowardConfidence })
        XCTAssertEqual(e.recommendation, .testRiskiestAssumption)
        XCTAssertEqual(e.nextStepText, "Ask five park owners how they handle their website today")
        XCTAssertEqual(e.experiment?.timeboxDays, 7)
        XCTAssertTrue(e.projectionSuggestion?.contains("$99–$199") ?? false)
        XCTAssertEqual(e.projectionEstimateLow, 900)
        XCTAssertEqual(e.projectionEstimateHigh, 2400)
        XCTAssertEqual(e.projectionEstimateBasis, "three competitors' pricing pages")
        XCTAssertNil(e.projectionPricePerUnit, "an estimate never becomes the user's figure")
        XCTAssertNil(e.projectionPricePerUnit, "a range is an estimate, never a projection the user did not type")
        XCTAssertEqual(idea.stage, .evaluate)
        XCTAssertEqual(idea.lensType, .business)

        // Explorations: proposed, unconfirmed
        let problem = ExploreActions.latest(for: "problem", on: idea)
        XCTAssertEqual(problem?.aiText, "Parks have a Facebook page and nothing else.")
        XCTAssertFalse(problem?.confirmed ?? true)
        XCTAssertEqual(problem?.userText, "")

        // Panel as a Round
        XCTAssertEqual(applied.round.verdicts.count, 2)
        XCTAssertEqual(applied.round.verdicts.first { $0.sphere == .customer }?.kind, .cantTell)
        XCTAssertEqual(applied.round.verdicts.first { $0.sphere == .investor }?.sources.first?.id, page.id)
        XCTAssertEqual(applied.round.crossfire.count, 1)
        XCTAssertEqual(idea.originalText, "A website retainer for Texas RV parks")
    }

    func testApplyNeverOverwritesTheUsersOwnAnswerAndCapsRungs() throws {
        let idea = Idea(originalText: "x")
        store.context.insert(idea)
        ExploreActions.answer("My own words", promptKey: "problem", on: idea)
        let page = Source(kind: .web, title: "p", fullText: "t", sourceClass: .aiFound, url: "https://example.com")
        idea.sources.append(page)

        let applied = PrefillApplier.apply(canned(sourceID: page.id, rung: 5), rationale: "", costUSD: nil, to: idea, in: store.context)
        XCTAssertEqual(ExploreActions.latest(for: "problem", on: idea)?.userText, "My own words")
        XCTAssertNil(ExploreActions.latest(for: "problem", on: idea)?.aiText)
        XCTAssertTrue(applied.evaluation.criteria.allSatisfy { $0.evidenceLevel <= Scoring.deskResearchRungCeiling })
    }

    func testThePanelNamesTheIdeaUnlessThePersonDid() throws {
        let idea = Idea(originalText: "If what if there was a website care service for RV parks along one corridor")
        store.context.insert(idea)
        let page = Source(kind: .web, title: "p", fullText: "$149/mo", sourceClass: .aiFound, url: "https://example.com")
        idea.sources.append(page)
        var r = canned(sourceID: page.id)
        r.title = "\"Weekend RV park site care.\""
        PrefillApplier.apply(r, rationale: "", costUSD: nil, to: idea, in: store.context)
        XCTAssertEqual(idea.title, "Weekend RV park site care", "2 to 5 words, unquoted")

        let named = Idea(originalText: "Another idea about RV parks and their websites")
        named.title = "My RV thing"
        named.titleEdited = true
        store.context.insert(named)
        let page2 = Source(kind: .web, title: "p", fullText: "$149/mo", sourceClass: .aiFound, url: "https://example.com/2")
        named.sources.append(page2)
        var r2 = canned(sourceID: page2.id)
        r2.title = "Something the panel prefers"
        PrefillApplier.apply(r2, rationale: "", costUSD: nil, to: named, in: store.context)
        XCTAssertEqual(named.title, "My RV thing", "the person's name for it stays")
    }

    func testUserScoringClearsTheProposalFlag() throws {
        let idea = Idea(originalText: "x")
        store.context.insert(idea)
        let applied = PrefillApplier.apply(canned(sourceID: UUID()), rationale: "", costUSD: nil, to: idea, in: store.context)
        try applied.evaluation.set(key: "A2", score: 1, evidenceLevel: 1)
        XCTAssertFalse(applied.evaluation.criterionScore(for: "A2")?.aiProposed ?? true)
        XCTAssertTrue(applied.evaluation.criterionScore(for: "A1")?.aiProposed ?? false)
    }

    func testResearchPagesBecomeChunkedSources() throws {
        let idea = Idea(originalText: "x")
        store.context.insert(idea)
        let long = Array(repeating: "A paragraph of about sixty characters for chunking purposes here.", count: 60).joined(separator: "\n\n")
        let saved = PrefillApplier.saveResearch([
            .init(url: "https://a.example", title: "A", text: long, kind: "fetched", retrievedAt: nil),
            .init(url: "https://b.example", title: "B", text: "", kind: "searchHit", retrievedAt: nil),
            .init(url: "https://a.example", title: "A again", text: "dup", kind: "fetched", retrievedAt: nil),
        ], notes: "- Claim one (https://a.example)", to: idea)
        XCTAssertEqual(saved.count, 2, "one fetched page plus the notes; hits and duplicates skipped")
        XCTAssertEqual(saved[0].sourceClass, .aiFound)
        XCTAssertEqual(saved[0].kind, .web)
        XCTAssertGreaterThan(saved[0].chunks.count, 2)
        XCTAssertTrue(saved[0].chunks.allSatisfy { $0.text.count <= 1300 })
        XCTAssertEqual(saved[1].title, "Research notes")
        XCTAssertEqual(idea.sources.count, 2)
    }

    func testPagesTheNotesCiteBecomeGradedSources() throws {
        let idea = Idea(originalText: "Website care for RV parks")
        store.context.insert(idea)
        let saved = PrefillApplier.saveResearch([
            .init(url: "https://www.g2.com/products/campspot/reviews", title: "Campspot reviews", text: "- Owners say the widget breaks on mobile", kind: "noted", retrievedAt: nil),
            .init(url: "https://www.reddit.com/r/RVLiving/comments/1", title: "reddit.com", text: "- An owner asks who builds park sites", kind: "noted", retrievedAt: nil),
        ], notes: "notes", to: idea)
        XCTAssertEqual(saved.count, 3, "two cited pages plus the notes")
        XCTAssertEqual(saved[0].url, "https://www.g2.com/products/campspot/reviews")
        XCTAssertEqual(saved[0].evidenceRank, .reviewed)
        XCTAssertEqual(saved[1].evidenceRank, .discussed)
        let grade = DeskGrade.level(sources: saved.prefix(2).map { ($0.url, $0.evidenceRank) }, proposedLevel: 2)
        XCTAssertEqual(grade.independentSources, 2)
        XCTAssertGreaterThan(grade.level, 1.0, "real pages lift a criterion off the floor")
    }

    func testSpendAccounting() {
        let suite = UserDefaults(suiteName: "forge.tests.spend.\(UUID().uuidString)")!
        AISpend.defaults = suite
        defer { AISpend.defaults = .standard }
        XCTAssertEqual(AISpend.spentUSD(), 0)
        XCTAssertEqual(AISpend.ceilingUSD, AISpend.defaultCeiling)
        AISpend.record(0.42)
        AISpend.record(0.08)
        XCTAssertEqual(AISpend.spentUSD(), 0.5, accuracy: 0.0001)
        AISpend.ceilingUSD = 1
        XCTAssertTrue(AISpend.wouldExceed(estimate: 0.6))
        XCTAssertFalse(AISpend.wouldExceed(estimate: 0.4))
        let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: .now)!
        XCTAssertEqual(AISpend.spentUSD(now: nextMonth), 0, "a new month starts at zero")
        XCTAssertEqual(AISpend.format(0.004), "<$0.01")
    }

    func testJSONValueRoundTrips() throws {
        let json = #"{"role":"assistant","content":[{"type":"text","text":"hi"},{"n":1.5,"ok":true,"none":null}]}"#
        let value = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
        let data = try JSONEncoder().encode(value)
        let again = try JSONDecoder().decode(JSONValue.self, from: data)
        XCTAssertEqual(value, again)
    }
}
