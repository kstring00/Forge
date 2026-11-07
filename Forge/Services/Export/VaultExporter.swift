import Foundation
import SwiftData
import ForgeCore

/// Builds an export document from the store, encodes it, renders Markdown, and
/// writes the export folder: vault.json, vault.md and the voice recordings.
enum VaultExporter {

    // MARK: Document

    static func document(from context: ModelContext, now: Date = .now) throws -> VaultExportDocument {
        let ideas = try context.fetch(FetchDescriptor<Idea>(sortBy: [SortDescriptor(\Idea.createdAt)]))
        let decisions = try context.fetch(FetchDescriptor<Decision>(sortBy: [SortDescriptor(\Decision.date)]))
        let pitches = try context.fetch(FetchDescriptor<Pitch>(sortBy: [SortDescriptor(\Pitch.createdAt)]))
        let advantages = try context.fetch(FetchDescriptor<Advantage>(sortBy: [SortDescriptor(\Advantage.createdAt)]))
        let constraints = try context.fetch(FetchDescriptor<Constraint>(sortBy: [SortDescriptor(\Constraint.createdAt)]))
        let charter = try context.fetch(FetchDescriptor<StewardCharter>()).first

        return VaultExportDocument(
            exportedAt: now,
            ideas: ideas.map(export),
            decisions: decisions.map(export),
            pitches: pitches.map(export),
            advantages: advantages.map { AdvantageExport(id: $0.id, text: $0.text, kind: $0.kindRaw, createdAt: $0.createdAt) },
            constraints: constraints.map { ConstraintExport(id: $0.id, text: $0.text, createdAt: $0.createdAt, fromPitchID: $0.fromPitch?.id) },
            stewardCharter: charter.flatMap { $0.isPlaceholder ? nil : $0.text }
        )
    }

    static func export(_ idea: Idea) -> IdeaExport {
        IdeaExport(
            id: idea.id, title: idea.title, originalText: idea.originalText,
            aiSummary: idea.aiSummary, aiSummaryConfirmed: idea.aiSummaryConfirmed,
            lensType: idea.lensTypeRaw, stage: idea.stageRaw, tags: idea.tags, notes: idea.notes,
            createdAt: idea.createdAt, updatedAt: idea.updatedAt, archivedAt: idea.archivedAt,
            origin: idea.originRaw, pivotType: idea.pivotTypeRaw, pivotOfID: idea.pivotOf?.id,
            audioFileName: idea.audioFileName,
            triage: idea.triage.map { TriageExport(id: $0.id, answers: $0.answersRaw, completedAt: $0.completedAt) },
            explorations: idea.explorations.sorted { $0.createdAt < $1.createdAt }.map {
                ExplorationExport(id: $0.id, createdAt: $0.createdAt, promptKey: $0.promptKey,
                                  userText: $0.userText, aiText: $0.aiText, confirmed: $0.confirmed)
            },
            evaluations: idea.evaluations.sorted { $0.version < $1.version }.map(export),
            sources: idea.sources.sorted { $0.capturedAt < $1.capturedAt }.map(export),
            artifacts: idea.artifacts.sorted { $0.createdAt < $1.createdAt }.map {
                ArtifactExport(id: $0.id, kind: $0.kindRaw, content: $0.content, audioRef: $0.audioRef, createdAt: $0.createdAt)
            },
            rounds: idea.rounds.sorted { $0.createdAt < $1.createdAt }.map(export),
            realityChecks: idea.realityChecks.sorted { $0.createdAt < $1.createdAt }.map(export),
            project: idea.project.map(export)
        )
    }

    static func export(_ e: Evaluation) -> EvaluationExport {
        EvaluationExport(
            id: e.id, version: e.version, lensType: e.lensTypeRaw, createdAt: e.createdAt,
            finalizedAt: e.finalizedAt, potential: e.potential, confidence: e.confidence,
            shortfallTexts: e.shortfallTexts, riskiestAssumption: e.riskiestAssumption,
            recommendation: e.recommendationRaw,
            projectionPricePerUnit: e.projectionPricePerUnit,
            projectionUnitsYearOne: e.projectionUnitsYearOne,
            projectionRecurringPerMonth: e.projectionRecurringPerMonth,
            impactWho: e.impactWho,
            impactWhatChanges: e.impactWhatChanges,
            impactSignal: e.impactSignal,
            riskiestAssumptionConsequence: e.riskiestAssumptionConsequence,
            nextStepText: e.nextStepText,
            aiFilledAt: e.aiFilledAt,
            projectionSuggestion: e.projectionSuggestion,
            criteria: e.criteria.sorted { $0.key < $1.key }.map { c in
                CriterionScoreExport(
                    id: c.id, key: c.key, score: c.score, evidenceLevel: c.evidenceLevel,
                    note: c.note, peopleAtRung: c.peopleAtRung, aiProposed: c.aiProposed,
                    evidence: c.evidence.sorted { $0.createdAt < $1.createdAt }.map(export))
            },
            experiment: e.experiment.map(export)
        )
    }

    static func export(_ ev: Evidence) -> EvidenceExport {
        EvidenceExport(id: ev.id, criterionKey: ev.criterionKey, ladderRung: ev.ladderRung,
                       text: ev.text, createdAt: ev.createdAt, sourceID: ev.source?.id)
    }

    static func export(_ x: Experiment) -> ExperimentExport {
        ExperimentExport(id: x.id, hypothesis: x.hypothesis, test: x.test, metric: x.metric, cost: x.cost,
                         timeboxDays: x.timeboxDays, decisionRule: x.decisionRule, outcome: x.outcome, createdAt: x.createdAt)
    }

    static func export(_ s: Source) -> SourceExport {
        SourceExport(id: s.id, kind: s.kindRaw, title: s.title, url: s.url, fileRef: s.fileRef,
                     fullText: s.fullText, aiSummary: s.aiSummary, sourceClass: s.sourceClassRaw,
                     reviewed: s.reviewed, capturedAt: s.capturedAt,
                     chunks: s.chunks.sorted { $0.index < $1.index }.map { ChunkExport(id: $0.id, index: $0.index, text: $0.text) })
    }

    static func export(_ r: Round) -> RoundExport {
        RoundExport(
            id: r.id, pitchText: r.pitchText, createdAt: r.createdAt, summary: r.summary,
            verdicts: r.verdicts.map { v in
                VerdictExport(
                    id: v.id, sphere: v.sphereRaw, kind: v.kindRaw, criterionKey: v.criterionKey,
                    reason: v.reason, evidenceNeeded: v.evidenceNeeded, sourceIDs: v.sources.map(\.id),
                    ruling: v.ruling.map { ru in
                        RulingExport(id: ru.id, choice: ru.choiceRaw, note: ru.note, createdAt: ru.createdAt,
                                     resultingDecisionID: ru.resultingDecision?.id,
                                     resultingEvidenceID: ru.resultingEvidence?.id,
                                     resultingAssumptionID: ru.resultingAssumption?.id,
                                     resultingExperiment: ru.resultingExperiment.map(export))
                    })
            },
            crossfire: r.crossfire.map { CrossfireExport(id: $0.id, fromSphere: $0.fromSphereRaw, toSphere: $0.toSphereRaw, text: $0.text) }
        )
    }

    static func export(_ rc: RealityCheck) -> RealityCheckExport {
        RealityCheckExport(
            id: rc.id, createdAt: rc.createdAt, verdict: rc.verdictRaw, summary: rc.summary,
            demandSignals: rc.demandSignals, gapMap: rc.gapMap, fitNotes: rc.fitNotes,
            limitsNote: rc.limitsNote, costEstimate: rc.costEstimate,
            rationale: rc.rationale, actualCostUSD: rc.actualCostUSD, draftedAssetSourceID: rc.draftedAssetSourceID,
            sourceIDs: rc.sources.map(\.id),
            competitors: rc.competitors.map {
                CompetitorExport(id: $0.id, name: $0.name, url: $0.url, pricing: $0.pricing, positioning: $0.positioning,
                                 praises: $0.praises, complaints: $0.complaints, tractionSignals: $0.tractionSignals,
                                 fetchedAt: $0.fetchedAt, sourceID: $0.source?.id)
            },
            experiment: rc.experiment.map(export)
        )
    }

    static func export(_ p: Project) -> ProjectExport {
        ProjectExport(
            id: p.id, name: p.name, projectDescription: p.projectDescription, desiredOutcome: p.desiredOutcome,
            status: p.statusRaw, notes: p.notes, resources: p.resources, nextStep: p.nextStep,
            launchDefinition: p.launchDefinition, retrospective: p.retrospective,
            createdAt: p.createdAt, pausedAt: p.pausedAt, completedAt: p.completedAt,
            milestones: p.orderedMilestones.map { m in
                MilestoneExport(id: m.id, title: m.title, order: m.order, done: m.done,
                                tasks: m.tasks.sorted { $0.createdAt < $1.createdAt }.map {
                                    TaskExport(id: $0.id, title: $0.title, done: $0.done, createdAt: $0.createdAt, completedAt: $0.completedAt)
                                })
            }
        )
    }

    static func export(_ d: Decision) -> DecisionExport {
        DecisionExport(id: d.id, kind: d.kindRaw, decision: d.text, decidedAt: d.date, beliefs: d.beliefs,
                       reasoning: d.reason, expectedResult: d.expectedResult, expectedBy: d.expectedBy,
                       actualResult: d.actualResult, recordedAt: d.recordedAt,
                       ideaID: d.idea?.id, projectID: d.project?.id)
    }

    static func export(_ p: Pitch) -> PitchExport {
        PitchExport(id: p.id, title: p.title, body: p.body, forWhom: p.forWhom, whyNow: p.whyNow,
                    advantageUsed: p.advantageUsed, riskiestAssumption: p.riskiestAssumption,
                    cluster: p.clusterRaw, sphere: p.sphereRaw, createdAt: p.createdAt,
                    status: p.statusRaw, rejectionReason: p.rejectionReason, savedIdeaID: p.savedIdea?.id)
    }

    // MARK: Coding

    static func encode(_ doc: VaultExportDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(doc)
    }

    static func decode(_ data: Data) throws -> VaultExportDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(VaultExportDocument.self, from: data)
    }

    // MARK: Markdown

    static func markdown(_ doc: VaultExportDocument) -> String {
        var out: [String] = []
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short

        out.append("# FORGE Vault")
        out.append("")
        out.append("Exported \(df.string(from: doc.exportedAt)). \(doc.ideas.count) \(doc.ideas.count == 1 ? "idea" : "ideas").")
        out.append("")

        for idea in doc.ideas {
            out.append("## \(idea.title)")
            out.append("")
            var meta = ["Stage: \(idea.stage)"]
            if let lens = idea.lensType { meta.append("Lens: \(lens)") }
            meta.append("Captured: \(df.string(from: idea.createdAt))")
            if !idea.tags.isEmpty { meta.append("Tags: \(idea.tags.joined(separator: ", "))") }
            if idea.archivedAt != nil { meta.append("Archived") }
            if idea.pivotOfID != nil, let type = idea.pivotType { meta.append("Pivot (\(type))") }
            out.append(meta.map { "- \($0)" }.joined(separator: "\n"))
            out.append("")
            out.append("### Original")
            out.append("")
            out.append(idea.originalText.split(separator: "\n", omittingEmptySubsequences: false).map { "> \($0)" }.joined(separator: "\n"))
            out.append("")
            if let summary = idea.aiSummary, idea.aiSummaryConfirmed {
                out.append("_AI summary (confirmed): \(summary)_")
                out.append("")
            }
            if !idea.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                out.append("### Notes")
                out.append("")
                out.append(idea.notes)
                out.append("")
            }
            if !idea.explorations.isEmpty {
                out.append("### Exploration")
                out.append("")
                for ex in idea.explorations {
                    out.append("**\(ex.promptKey)** \(ex.userText)")
                    if let ai = ex.aiText, ex.confirmed { out.append("_AI: \(ai)_") }
                    out.append("")
                }
            }
            if !idea.evaluations.isEmpty {
                out.append("### Evaluations")
                out.append("")
                for e in idea.evaluations {
                    var line = "- v\(e.version) (\(e.lensType)): Potential \(e.potential), Confidence \(e.confidence)"
                    if let rec = e.recommendation { line += ", \(rec)" }
                    out.append(line)
                    if !e.riskiestAssumption.isEmpty { out.append("  - Riskiest assumption: \(e.riskiestAssumption)") }
                    for c in e.criteria { out.append("  - \(c.key): score \(c.score), evidence \(c.evidenceLevel)") }
                }
                out.append("")
            }
            if !idea.realityChecks.isEmpty {
                out.append("### Reality checks")
                out.append("")
                for rc in idea.realityChecks {
                    out.append("- \(df.string(from: rc.createdAt)): **\(rc.verdict)**. \(rc.summary)")
                    for c in rc.competitors { out.append("  - \(c.name) \(c.pricing.isEmpty ? "" : "(\(c.pricing))") \(c.positioning)") }
                }
                out.append("")
            }
            let ideaDecisions = doc.decisions.filter { $0.ideaID == idea.id || ($0.projectID != nil && $0.projectID == idea.project?.id) }
            if !ideaDecisions.isEmpty {
                out.append("### Decisions")
                out.append("")
                for d in ideaDecisions {
                    out.append("- \(df.string(from: d.decidedAt)) [\(d.kind)] \(d.decision)")
                    if !d.expectedResult.isEmpty { out.append("  - Expected: \(d.expectedResult)") }
                    if let actual = d.actualResult { out.append("  - Actually: \(actual)") }
                }
                out.append("")
            }
            if let p = idea.project {
                out.append("### Project: \(p.name)")
                out.append("")
                out.append("- Status: \(p.status)")
                if !p.desiredOutcome.isEmpty { out.append("- Desired outcome: \(p.desiredOutcome)") }
                if let next = p.nextStep { out.append("- Next step: \(next)") }
                for m in p.milestones {
                    out.append("- [\(m.done ? "x" : " ")] \(m.title)")
                    for t in m.tasks { out.append("  - [\(t.done ? "x" : " ")] \(t.title)") }
                }
                out.append("")
            }
            if !idea.sources.isEmpty {
                out.append("### Sources")
                out.append("")
                for s in idea.sources {
                    out.append("- \(s.title) (\(s.sourceClass)\(s.reviewed ? ", reviewed" : ""))\(s.url.map { " <\($0)>" } ?? "")")
                }
                out.append("")
            }
        }

        if !doc.pitches.isEmpty {
            out.append("## Pitches")
            out.append("")
            for p in doc.pitches { out.append("- [\(p.status)] \(p.title): \(p.body)") }
            out.append("")
        }
        if !doc.advantages.isEmpty {
            out.append("## Advantages")
            out.append("")
            for a in doc.advantages { out.append("- \(a.text) (\(a.kind))") }
            out.append("")
        }
        if !doc.constraints.isEmpty {
            out.append("## Constraints")
            out.append("")
            for c in doc.constraints { out.append("- \(c.text)") }
            out.append("")
        }
        if let charter = doc.stewardCharter {
            out.append("## Steward charter")
            out.append("")
            out.append(charter)
            out.append("")
        }
        return out.joined(separator: "\n")
    }

    // MARK: Files

    /// Writes "FORGE Export <date>/" under `parent` with vault.json, vault.md and
    /// a recordings folder holding every referenced voice file that exists.
    @discardableResult
    static func writeBundle(_ doc: VaultExportDocument, to parent: URL,
                            recordingsFrom recordingsDir: URL = RecordingStore.directory) throws -> URL {
        let stamp = DateFormatter()
        stamp.dateFormat = "yyyy-MM-dd HHmm"
        let folder = parent.appendingPathComponent("FORGE Export \(stamp.string(from: doc.exportedAt))", isDirectory: true)
        let fm = FileManager.default
        if fm.fileExists(atPath: folder.path) { try fm.removeItem(at: folder) }
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)

        try encode(doc).write(to: folder.appendingPathComponent(VaultExportDocument.fileName), options: .atomic)
        try markdown(doc).data(using: .utf8)?.write(to: folder.appendingPathComponent(VaultExportDocument.markdownFileName), options: .atomic)

        let names = doc.ideas.compactMap(\.audioFileName)
        if !names.isEmpty {
            let rec = folder.appendingPathComponent(VaultExportDocument.recordingsFolder, isDirectory: true)
            try fm.createDirectory(at: rec, withIntermediateDirectories: true)
            for name in names {
                let src = recordingsDir.appendingPathComponent(name)
                if fm.fileExists(atPath: src.path) {
                    try fm.copyItem(at: src, to: rec.appendingPathComponent(name))
                }
            }
        }
        return folder
    }
}
