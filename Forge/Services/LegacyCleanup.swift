import Foundation
import SwiftData
import ForgeCore

/// One pass over records written before a rule existed, run at launch and
/// kept idempotent: source ids the model wrote into prose become titles or go;
/// a step's target is read from its text when it was stored as the default;
/// a long title becomes a short one (2 to 5 words).
enum LegacyCleanup {
    static let versionKey = "legacyCleanup.version"
    static let version = 3

    @MainActor
    static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: versionKey) < version else { return }
        run(in: context)
        defaults.set(version, forKey: versionKey)
    }

    @MainActor
    static func run(in context: ModelContext) {
        guard let ideas = try? context.fetch(FetchDescriptor<Idea>()) else { return }
        for idea in ideas {
            let titles = Dictionary(uniqueKeysWithValues: idea.sources.map { ($0.id, $0.title) })
            func clean(_ s: String) -> String { IDScrub.scrub(s, titles: titles) }
            func cleanOpt(_ s: String?) -> String? { s.map(clean) }

            for check in idea.realityChecks {
                check.summary = clean(check.summary)
                check.gapMap = clean(check.gapMap)
                check.fitNotes = clean(check.fitNotes)
                check.rationale = cleanOpt(check.rationale)
                check.demandSignals = check.demandSignals.map { DemandSignal(text: clean($0.text), url: $0.url, rung: $0.rung, sourceID: $0.sourceID) }
                for c in check.competitors {
                    c.name = clean(c.name); c.pricing = clean(c.pricing); c.positioning = clean(c.positioning)
                    c.praises = c.praises.map(clean); c.complaints = c.complaints.map(clean); c.tractionSignals = c.tractionSignals.map(clean)
                }
                if let x = check.experiment { scrub(x, clean) }
            }
            for round in idea.rounds {
                round.summary = cleanOpt(round.summary)
                for v in round.verdicts {
                    v.reason = clean(v.reason)
                    v.evidenceNeeded = cleanOpt(v.evidenceNeeded)
                }
                for c in round.crossfire { c.text = clean(c.text) }
            }
            for e in idea.evaluations {
                e.riskiestAssumption = clean(e.riskiestAssumption)
                e.riskiestAssumptionConsequence = cleanOpt(e.riskiestAssumptionConsequence)
                e.nextStepText = cleanOpt(e.nextStepText)
                e.projectionSuggestion = cleanOpt(e.projectionSuggestion)
                for s in e.criteria {
                    s.note = clean(s.note)
                    for ev in s.evidence { ev.text = clean(ev.text) }
                }
                if let x = e.experiment { scrub(x, clean) }
            }
            for ex in idea.explorations { ex.aiText = cleanOpt(ex.aiText) }
            for s in idea.sources where s.kind == .note {
                s.title = clean(s.title)
                s.fullText = clean(s.fullText)
                for ch in s.chunks { ch.text = clean(ch.text) }
            }
            // v3: every idea has a 2-to-5-word name; one the person typed is left alone.
            if !idea.titleEdited && ShortTitle.wordCount(idea.title) > ShortTitle.maxWords {
                idea.title = ShortTitle.make(from: idea.originalText)
            }
            if let project = idea.project {
                project.nextStep = cleanOpt(project.nextStep)
                project.nextStepCaveat = cleanOpt(project.nextStepCaveat)
                project.notes = project.notes.map(clean)
                if project.nextStepTarget <= 1, let step = project.nextStep,
                   let n = NumberWords.firstNumber(in: step), (2...50).contains(n) {
                    project.nextStepTarget = n
                }
            }
        }
        try? context.save()
    }

    private static func scrub(_ x: Experiment, _ clean: (String) -> String) {
        x.hypothesis = clean(x.hypothesis); x.test = clean(x.test); x.metric = clean(x.metric); x.decisionRule = clean(x.decisionRule)
    }
}
