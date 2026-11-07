import Foundation
import SwiftData
import ForgeCore

struct ImportSummary: Equatable {
    var schemaVersion = 0
    var ideasImported = 0
    var ideasSkipped = 0
    var decisionsImported = 0
    var pitchesImported = 0
    var advantagesImported = 0
    var constraintsImported = 0
    var recordingsCopied = 0
    var charterImported = false
}

enum ImportError: LocalizedError {
    case unsupportedSchema(Int)
    case noVaultFile

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let v): "This export was made by a newer FORGE (schema \(v)). Update the app and try again."
        case .noVaultFile: "That folder doesn't contain a vault.json."
        }
    }
}

/// Restores an export into a store. Additive and idempotent: anything whose ID
/// already exists is left alone, nothing is overwritten, nothing is deleted.
enum VaultImporter {

    static func importDocument(_ doc: VaultExportDocument, into context: ModelContext,
                               recordingsFrom recordingsDir: URL? = nil) throws -> ImportSummary {
        guard doc.schemaVersion <= VaultExportDocument.currentSchemaVersion else {
            throw ImportError.unsupportedSchema(doc.schemaVersion)
        }
        var summary = ImportSummary(schemaVersion: doc.schemaVersion)

        // Lookup tables seeded with what is already in the store, so references
        // from imported records can land on existing ones.
        var ideas = try index(context, Idea.self)
        var sources = try index(context, Source.self)
        var evidence = try index(context, Evidence.self)
        var decisions = try index(context, Decision.self)
        var projects = try index(context, Project.self)
        var pitches = try index(context, Pitch.self)
        let advantages = try index(context, Advantage.self)
        let constraints = try index(context, Constraint.self)

        // Pass 1: ideas and everything nested in them, except rounds (which may
        // reference decisions) and pivot links (which may reference later ideas).
        var pendingRounds: [(Idea, [RoundExport])] = []
        var imported: [IdeaExport] = []
        for x in doc.ideas {
            if ideas[x.id] != nil {
                summary.ideasSkipped += 1
                continue
            }
            let idea = makeIdea(x)
            context.insert(idea)
            ideas[idea.id] = idea
            imported.append(x)

            for s in x.sources {
                let source = makeSource(s)
                idea.sources.append(source)
                sources[source.id] = source
            }
            if let t = x.triage {
                let triage = OpportunityFilter()
                triage.id = t.id
                triage.answersRaw = t.answers
                triage.completedAt = t.completedAt
                idea.triage = triage
            }
            for e in x.explorations {
                let ex = Exploration(promptKey: e.promptKey, userText: e.userText)
                ex.id = e.id
                ex.createdAt = e.createdAt
                ex.aiText = e.aiText
                ex.confirmed = e.confirmed
                idea.explorations.append(ex)
            }
            for e in x.evaluations {
                idea.evaluations.append(makeEvaluation(e, sources: sources, evidenceIndex: &evidence))
            }
            for a in x.artifacts {
                let artifact = LibraryArtifact(kind: ArtifactKind(rawValue: a.kind) ?? .brief, content: a.content, audioRef: a.audioRef)
                artifact.id = a.id
                artifact.createdAt = a.createdAt
                idea.artifacts.append(artifact)
            }
            for rc in x.realityChecks {
                idea.realityChecks.append(makeRealityCheck(rc, sources: sources))
            }
            if let p = x.project {
                let project = makeProject(p)
                idea.project = project
                projects[project.id] = project
            }
            pendingRounds.append((idea, x.rounds))
            summary.ideasImported += 1
        }

        // Pass 2: pivot links.
        for x in imported where x.pivotOfID != nil {
            if let child = ideas[x.id], let parent = x.pivotOfID.flatMap({ ideas[$0] }) {
                child.pivotOf = parent
            }
        }

        // Decisions (top-level; may point at ideas or projects, new or existing).
        for d in doc.decisions where decisions[d.id] == nil {
            let decision = Decision(kind: DecisionKind(rawValue: d.kind) ?? .commit, decision: d.decision,
                                    beliefs: d.beliefs, reasoning: d.reasoning, expectedResult: d.expectedResult,
                                    expectedBy: d.expectedBy, decidedAt: d.decidedAt)
            decision.id = d.id
            decision.actualResult = d.actualResult
            decision.recordedAt = d.recordedAt
            decision.idea = d.ideaID.flatMap { ideas[$0] }
            decision.project = d.projectID.flatMap { projects[$0] }
            context.insert(decision)
            decisions[decision.id] = decision
            summary.decisionsImported += 1
        }

        // Rounds, now that decisions and evidence exist.
        for (idea, rounds) in pendingRounds {
            for r in rounds {
                idea.rounds.append(makeRound(r, sources: sources, evidence: evidence, decisions: decisions))
            }
        }

        // Pitches, advantages, constraints, charter.
        for p in doc.pitches where pitches[p.id] == nil {
            let pitch = Pitch(title: p.title, body: p.body, forWhom: p.forWhom, whyNow: p.whyNow,
                              advantageUsed: p.advantageUsed, riskiestAssumption: p.riskiestAssumption,
                              cluster: PitchCluster(rawValue: p.cluster) ?? .asset,
                              sphere: p.sphere.flatMap(Sphere.init(rawValue:)))
            pitch.id = p.id
            pitch.createdAt = p.createdAt
            pitch.statusRaw = p.status
            pitch.rejectionReason = p.rejectionReason
            pitch.savedIdea = p.savedIdeaID.flatMap { ideas[$0] }
            context.insert(pitch)
            pitches[pitch.id] = pitch
            summary.pitchesImported += 1
        }
        for a in doc.advantages where advantages[a.id] == nil {
            let adv = Advantage(text: a.text, kind: AdvantageKind(rawValue: a.kind) ?? .skill)
            adv.id = a.id
            adv.createdAt = a.createdAt
            context.insert(adv)
            summary.advantagesImported += 1
        }
        for c in doc.constraints where constraints[c.id] == nil {
            let con = Constraint(text: c.text, fromPitch: c.fromPitchID.flatMap { pitches[$0] })
            con.id = c.id
            con.createdAt = c.createdAt
            context.insert(con)
            summary.constraintsImported += 1
        }
        if let text = doc.stewardCharter, !text.isEmpty {
            if let existing = try context.fetch(FetchDescriptor<StewardCharter>()).first {
                if existing.isPlaceholder {
                    existing.text = text
                    existing.updatedAt = Date()
                    summary.charterImported = true
                }
            } else {
                context.insert(StewardCharter(text: text))
                summary.charterImported = true
            }
        }

        // Recordings for the ideas imported this run.
        if let recordingsDir {
            let fm = FileManager.default
            for x in imported {
                guard let name = x.audioFileName else { continue }
                let from = recordingsDir.appendingPathComponent(name)
                let to = RecordingStore.url(for: name)
                if fm.fileExists(atPath: from.path), !fm.fileExists(atPath: to.path) {
                    try fm.copyItem(at: from, to: to)
                    summary.recordingsCopied += 1
                }
            }
        }

        try context.save()
        return summary
    }

    // MARK: Builders

    private static func index<T: PersistentModel & ExportIdentified>(_ context: ModelContext, _ type: T.Type) throws -> [UUID: T] {
        var out: [UUID: T] = [:]
        for item in try context.fetch(FetchDescriptor<T>()) { out[item.id] = item }
        return out
    }

    private static func makeIdea(_ x: IdeaExport) -> Idea {
        let idea = Idea(originalText: x.originalText, title: x.title,
                        origin: IdeaOrigin(rawValue: x.origin) ?? .captured, audioFileName: x.audioFileName)
        idea.id = x.id
        idea.aiSummary = x.aiSummary
        idea.aiSummaryConfirmed = x.aiSummaryConfirmed
        idea.lensTypeRaw = x.lensType
        idea.stageRaw = x.stage
        idea.tags = x.tags
        idea.notes = x.notes
        idea.pivotTypeRaw = x.pivotType
        idea.archivedAt = x.archivedAt
        idea.createdAt = x.createdAt
        idea.updatedAt = x.updatedAt
        return idea
    }

    private static func makeSource(_ s: SourceExport) -> Source {
        let source = Source(kind: SourceKind(rawValue: s.kind) ?? .note, title: s.title, fullText: s.fullText,
                            sourceClass: SourceClass(rawValue: s.sourceClass) ?? .assumption, url: s.url)
        source.id = s.id
        source.fileRef = s.fileRef
        source.aiSummary = s.aiSummary
        source.reviewed = s.reviewed
        source.capturedAt = s.capturedAt
        for c in s.chunks {
            let chunk = SourceChunk(index: c.index, text: c.text)
            chunk.id = c.id
            source.chunks.append(chunk)
        }
        return source
    }

    private static func makeExperiment(_ x: ExperimentExport) -> Experiment {
        let e = Experiment(hypothesis: x.hypothesis, test: x.test, metric: x.metric, cost: x.cost,
                           timeboxDays: x.timeboxDays, decisionRule: x.decisionRule)
        e.id = x.id
        e.outcome = x.outcome
        e.createdAt = x.createdAt
        return e
    }

    private static func makeEvaluation(_ e: EvaluationExport, sources: [UUID: Source],
                                       evidenceIndex: inout [UUID: Evidence]) -> Evaluation {
        let evaluation = Evaluation(lens: LensType(rawValue: e.lensType) ?? .business, version: e.version)
        evaluation.id = e.id
        evaluation.createdAt = e.createdAt
        evaluation.shortfallTexts = e.shortfallTexts
        evaluation.riskiestAssumption = e.riskiestAssumption
        evaluation.recommendationRaw = e.recommendation
        evaluation.projectionPricePerUnit = e.projectionPricePerUnit
        evaluation.projectionUnitsYearOne = e.projectionUnitsYearOne
        evaluation.projectionRecurringPerMonth = e.projectionRecurringPerMonth
        evaluation.impactWho = e.impactWho
        evaluation.impactWhatChanges = e.impactWhatChanges
        evaluation.impactSignal = e.impactSignal
        for c in e.criteria {
            let score = CriterionScore(key: c.key, score: c.score, evidenceLevel: c.evidenceLevel, note: c.note)
            score.id = c.id
            score.peopleAtRung = c.peopleAtRung
            for ev in c.evidence {
                let item = Evidence(criterionKey: ev.criterionKey, ladderRung: ev.ladderRung, text: ev.text,
                                    source: ev.sourceID.flatMap { sources[$0] })
                item.id = ev.id
                item.createdAt = ev.createdAt
                score.evidence.append(item)
                evidenceIndex[item.id] = item
            }
            evaluation.criteria.append(score)
        }
        evaluation.experiment = e.experiment.map(makeExperiment)
        evaluation.restore(potential: e.potential, confidence: e.confidence, finalizedAt: e.finalizedAt)
        return evaluation
    }

    private static func makeRealityCheck(_ rc: RealityCheckExport, sources: [UUID: Source]) -> RealityCheck {
        let check = RealityCheck(verdict: RealityVerdict(rawValue: rc.verdict) ?? .cantTell,
                                 summary: rc.summary, costEstimate: rc.costEstimate)
        check.id = rc.id
        check.createdAt = rc.createdAt
        check.demandSignals = rc.demandSignals
        check.gapMap = rc.gapMap
        check.fitNotes = rc.fitNotes
        check.limitsNote = rc.limitsNote
        check.sources = rc.sourceIDs.compactMap { sources[$0] }
        for c in rc.competitors {
            let competitor = Competitor(name: c.name, url: c.url, pricing: c.pricing, positioning: c.positioning,
                                        praises: c.praises, complaints: c.complaints, tractionSignals: c.tractionSignals,
                                        fetchedAt: c.fetchedAt, source: c.sourceID.flatMap { sources[$0] })
            competitor.id = c.id
            check.competitors.append(competitor)
        }
        check.experiment = rc.experiment.map(makeExperiment)
        return check
    }

    private static func makeProject(_ p: ProjectExport) -> Project {
        let project = Project(name: p.name, desiredOutcome: p.desiredOutcome)
        project.id = p.id
        project.projectDescription = p.projectDescription
        project.statusRaw = p.status
        project.notes = p.notes
        project.resources = p.resources
        project.nextStep = p.nextStep
        project.launchDefinition = p.launchDefinition
        project.retrospective = p.retrospective
        project.createdAt = p.createdAt
        project.pausedAt = p.pausedAt
        project.completedAt = p.completedAt
        for m in p.milestones {
            let milestone = Milestone(title: m.title, order: m.order)
            milestone.id = m.id
            milestone.done = m.done
            for t in m.tasks {
                let task = ProjectTask(title: t.title)
                task.id = t.id
                task.done = t.done
                task.createdAt = t.createdAt
                task.completedAt = t.completedAt
                milestone.tasks.append(task)
            }
            project.milestones.append(milestone)
        }
        return project
    }

    private static func makeRound(_ r: RoundExport, sources: [UUID: Source], evidence: [UUID: Evidence],
                                  decisions: [UUID: Decision]) -> Round {
        let round = Round(pitchText: r.pitchText)
        round.id = r.id
        round.createdAt = r.createdAt
        round.summary = r.summary
        for v in r.verdicts {
            let verdict = Verdict(sphere: Sphere(rawValue: v.sphere) ?? .skeptic,
                                  kind: VerdictKind(rawValue: v.kind) ?? .cantTell,
                                  criterionKey: v.criterionKey, reason: v.reason,
                                  sources: v.sourceIDs.compactMap { sources[$0] },
                                  evidenceNeeded: v.evidenceNeeded)
            verdict.id = v.id
            if let ru = v.ruling {
                let ruling = Ruling(choice: RulingChoice(rawValue: ru.choice) ?? .findOut, note: ru.note)
                ruling.id = ru.id
                ruling.createdAt = ru.createdAt
                ruling.resultingDecision = ru.resultingDecisionID.flatMap { decisions[$0] }
                ruling.resultingEvidence = ru.resultingEvidenceID.flatMap { evidence[$0] }
                ruling.resultingAssumption = ru.resultingAssumptionID.flatMap { sources[$0] }
                ruling.resultingExperiment = ru.resultingExperiment.map(makeExperiment)
                verdict.ruling = ruling
            }
            round.verdicts.append(verdict)
        }
        for c in r.crossfire {
            let cf = Crossfire(from: Sphere(rawValue: c.fromSphere) ?? .skeptic,
                               to: Sphere(rawValue: c.toSphere) ?? .investor, text: c.text)
            cf.id = c.id
            round.crossfire.append(cf)
        }
        return round
    }
}

/// Models the importer indexes by their stable UUID.
protocol ExportIdentified: AnyObject {
    var id: UUID { get }
}

extension Idea: ExportIdentified {}
extension Source: ExportIdentified {}
extension Evidence: ExportIdentified {}
extension Decision: ExportIdentified {}
extension Project: ExportIdentified {}
extension Pitch: ExportIdentified {}
extension Advantage: ExportIdentified {}
extension Constraint: ExportIdentified {}
