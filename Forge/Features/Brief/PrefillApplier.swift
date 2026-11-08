import Foundation
import SwiftData
import ForgeCore

/// Turns a PrefillResult into records. Everything it writes is AI-found:
/// scores flagged `aiProposed`, explorations unconfirmed, evidence pointing at
/// unreviewed sources (so Confidence stays honest), a Round holding the
/// panel's verdicts, and a RealityCheck tying it together.
enum PrefillApplier {
    struct Applied {
        let realityCheck: RealityCheck
        let evaluation: Evaluation
        let round: Round
        let draftedAsset: Source
    }

    @MainActor
    static func apply(_ r: PrefillResult, rationale: String, costUSD: Double?, to idea: Idea,
                      in context: ModelContext, now: Date = .now) -> Applied {
        let sources = Dictionary(uniqueKeysWithValues: idea.sources.map { ($0.id, $0) })
        func source(_ id: UUID?) -> Source? { id.flatMap { sources[$0] } }
        func sourcesFor(_ ids: [UUID]) -> [Source] { ids.compactMap { sources[$0] } }
        // The model sometimes writes a source id into prose. Titles instead, never ids.
        let titles = Dictionary(uniqueKeysWithValues: idea.sources.map { ($0.id, $0.title) })
        func clean(_ text: String) -> String { IDScrub.scrub(text, titles: titles) }
        func cleanOpt(_ text: String?) -> String? { text.map { IDScrub.scrub($0, titles: titles) } }

        // Drafted asset, saved as a Source so the task can carry it.
        let asset = Source(kind: .note, title: clean(r.draftedAssets.title), fullText: clean(r.draftedAssets.body), sourceClass: .aiFound)
        asset.chunks.append(SourceChunk(index: 0, text: asset.fullText))
        idea.sources.append(asset)

        // Reality Check.
        let check = RealityCheck(verdict: r.realityCheck.verdict, summary: clean(r.realityCheck.summary), costEstimate: r.realityCheck.costEstimate)
        check.createdAt = now
        check.rationale = clean(rationale)
        check.actualCostUSD = costUSD
        check.gapMap = clean(r.realityCheck.gapMap)
        check.fitNotes = clean(r.realityCheck.fitNotes)
        check.draftedAssetSourceID = asset.id
        check.demandSignals = r.realityCheck.demandSignals.map { DemandSignal(text: clean($0.text), url: $0.url, rung: $0.rung, sourceID: $0.sourceID) }
        for c in r.realityCheck.competitors {
            check.competitors.append(Competitor(name: clean(c.name), url: c.url, pricing: clean(c.pricing), positioning: clean(c.positioning),
                                                praises: c.praises.map(clean), complaints: c.complaints.map(clean), tractionSignals: c.tractionSignals.map(clean),
                                                fetchedAt: now, source: source(c.sourceID)))
        }
        if let x = r.realityCheck.experiment {
            check.experiment = Experiment(hypothesis: clean(x.hypothesis), test: clean(x.test), metric: clean(x.metric), cost: x.cost, timeboxDays: x.timeboxDays, decisionRule: clean(x.decisionRule))
        }
        var cited = Set<UUID>()
        for id in r.realityCheck.competitors.compactMap(\.sourceID) + r.realityCheck.demandSignals.compactMap(\.sourceID) { cited.insert(id) }
        check.sources = sourcesFor(Array(cited)) + [asset]
        idea.realityChecks.append(check)

        // Explorations: the Spheres' proposed answers, unconfirmed until the user says so.
        for e in r.explorations {
            let existing = ExploreActions.latest(for: e.promptKey, on: idea)
            if let existing, !existing.userText.isEmpty { continue }   // never overwrite the user's own answer
            let ex = existing ?? Exploration(promptKey: e.promptKey)
            ex.aiText = clean(e.answer)
            ex.confirmed = false
            if existing == nil { idea.explorations.append(ex) }
        }

        // Evaluation: a new version, every score flagged as the panel's proposal.
        let evaluation = idea.beginEvaluation(lens: .business)
        for c in r.criteria {
            let rung = min(c.evidenceLevel, Scoring.deskResearchRungCeiling)
            let note = clean(c.note)
            try? evaluation.set(key: c.key, score: c.score, evidenceLevel: rung, note: note)
            if let score = evaluation.criterionScore(for: c.key) {
                score.aiProposed = true
                for s in sourcesFor(c.sourceIDs) {
                    score.evidence.append(Evidence(criterionKey: c.key, ladderRung: rung, text: note, source: s))
                }
            }
        }
        evaluation.recompute()
        evaluation.riskiestAssumption = clean(r.riskiestAssumption.belief)
        evaluation.riskiestAssumptionConsequence = clean(r.riskiestAssumption.consequence)
        evaluation.recommendation = r.nextMove.recommendation
        evaluation.nextStepText = clean(r.nextMove.step)
        if let x = r.nextMove.experiment {
            evaluation.experiment = Experiment(hypothesis: clean(x.hypothesis), test: clean(x.test), metric: clean(x.metric), cost: x.cost, timeboxDays: x.timeboxDays, decisionRule: clean(x.decisionRule))
        }
        if let p = r.projection {
            evaluation.projectionSuggestion = clean("\(Projection.compact(p.pricePerUnitLow))–\(Projection.compact(p.pricePerUnitHigh)) per unit · \(p.unitsYearOneLow)–\(p.unitsYearOneHigh) units in year one. \(p.rationale)")
        }
        if let low = r.projectionLow, let high = r.projectionHigh, high > 0 {
            evaluation.projectionEstimateLow = min(low, high)
            evaluation.projectionEstimateHigh = max(low, high)
            evaluation.projectionEstimateBasis = cleanOpt(r.projectionBasis).flatMap { $0.isEmpty ? nil : $0 }
        } else if let p = r.projection, p.pricePerUnitLow > 0, p.unitsYearOneLow > 0 {
            // An older proxy: price × units, per month, from the range it did give.
            evaluation.projectionEstimateLow = p.pricePerUnitLow * Double(p.unitsYearOneLow)
            evaluation.projectionEstimateHigh = p.pricePerUnitHigh * Double(p.unitsYearOneHigh)
            evaluation.projectionEstimateBasis = cleanOpt(p.rationale.isEmpty ? nil : p.rationale)
        }
        evaluation.aiFilledAt = now

        // The panel, as a Round the user can rule on in 3c.
        let round = Round(pitchText: idea.originalText)
        round.createdAt = now
        round.summary = clean(rationale)
        for v in r.panel {
            round.verdicts.append(Verdict(sphere: v.sphere, kind: v.verdict, criterionKey: v.criterionKey, reason: clean(v.reason),
                                          sources: sourcesFor(v.sourceIDs), evidenceNeeded: cleanOpt(v.evidenceNeeded)))
        }
        for c in r.crossfire {
            round.crossfire.append(Crossfire(from: c.from, to: c.to, text: clean(c.text)))
        }
        idea.rounds.append(round)

        idea.stage = .evaluate
        idea.touch()
        return Applied(realityCheck: check, evaluation: evaluation, round: round, draftedAsset: asset)
    }

    /// Research pages become ai-found web Sources with chunks for citation.
    @MainActor
    static func saveResearch(_ sources: [ResearchResponse.Source], notes: String, to idea: Idea) -> [Source] {
        var saved: [Source] = []
        // Seeded with what the Library already holds, then grown as this batch is
        // saved, so two fetches of one URL in the same run save once.
        var seenURLs = Set(idea.sources.compactMap(\.url))
        for s in sources where s.kind == "fetched" && !s.text.isEmpty && !seenURLs.contains(s.url) {
            seenURLs.insert(s.url)
            let source = Source(kind: .web, title: s.title.isEmpty ? s.url : s.title, fullText: s.text, sourceClass: .aiFound, url: s.url)
            for (i, chunk) in chunks(of: s.text).enumerated() {
                source.chunks.append(SourceChunk(index: i, text: chunk))
            }
            idea.sources.append(source)
            saved.append(source)
        }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            let note = Source(kind: .text, title: "Research notes", fullText: trimmed, sourceClass: .aiFound)
            for (i, chunk) in chunks(of: trimmed).enumerated() { note.chunks.append(SourceChunk(index: i, text: chunk)) }
            idea.sources.append(note)
            saved.append(note)
        }
        return saved
    }

    /// Paragraph-aware chunks of roughly 1,200 characters.
    static func chunks(of text: String, target: Int = 1200) -> [String] {
        var out: [String] = []
        var current = ""
        for para in text.components(separatedBy: "\n\n") {
            let p = para.trimmingCharacters(in: .whitespacesAndNewlines)
            if p.isEmpty { continue }
            if current.count + p.count + 2 > target, !current.isEmpty {
                out.append(current)
                current = ""
            }
            if p.count > target * 2 {
                var rest = Substring(p)
                while !rest.isEmpty {
                    let piece = rest.prefix(target)
                    out.append(String(piece))
                    rest = rest.dropFirst(piece.count)
                }
                continue
            }
            current = current.isEmpty ? p : current + "\n\n" + p
        }
        if !current.isEmpty { out.append(current) }
        return out
    }
}
