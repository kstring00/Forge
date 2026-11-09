import Foundation
import SwiftData
import ForgeCore

/// A captured idea. `originalText` is set once, in `init`, and has no setter
/// outside this class. Everything else may change; the raw thought never does.
@Model
public final class Idea {
    public var id: UUID = UUID()
    public var title: String = ""
    /// The person renamed it; the panel's proposed title never overwrites theirs.
    public var titleEdited: Bool = false
    /// Decision 0037: every change in proof from the world, newest last.
    public var proofMoves: [ProofMove] = []
    public private(set) var originalText: String = ""
    public var aiSummary: String?
    public var aiSummaryConfirmed: Bool = false
    public var lensTypeRaw: String?
    public var stageRaw: String = Stage.capture.rawValue
    public var tags: [String] = []
    public var notes: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var archivedAt: Date?
    public var originRaw: String = IdeaOrigin.captured.rawValue
    public var pivotTypeRaw: String?
    /// File name of the voice recording this idea was captured from, if any.
    public var audioFileName: String?

    // Relationships. All optional or defaulted so CloudKit can be enabled later.
    public var pivotOf: Idea?
    @Relationship(inverse: \Idea.pivotOf) public var pivots: [Idea] = []
    @Relationship(deleteRule: .cascade) public var triage: OpportunityFilter?
    @Relationship(deleteRule: .cascade, inverse: \Exploration.idea) public var explorations: [Exploration] = []
    @Relationship(deleteRule: .cascade, inverse: \Evaluation.idea) public var evaluations: [Evaluation] = []
    @Relationship(deleteRule: .cascade, inverse: \Source.idea) public var sources: [Source] = []
    @Relationship(deleteRule: .cascade, inverse: \LibraryArtifact.idea) public var artifacts: [LibraryArtifact] = []
    @Relationship(deleteRule: .cascade, inverse: \Round.idea) public var rounds: [Round] = []
    @Relationship(deleteRule: .cascade, inverse: \RealityCheck.idea) public var realityChecks: [RealityCheck] = []
    @Relationship(deleteRule: .cascade, inverse: \Decision.idea) public var decisions: [Decision] = []
    @Relationship(deleteRule: .cascade, inverse: \Project.idea) public var project: Project?

    public init(originalText: String, title: String? = nil, origin: IdeaOrigin = .captured, audioFileName: String? = nil) {
        self.id = UUID()
        self.originalText = originalText
        self.title = title ?? Idea.suggestedTitle(from: originalText)
        self.originRaw = origin.rawValue
        self.audioFileName = audioFileName
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    // MARK: Typed accessors

    public var stage: Stage {
        get { Stage(rawValue: stageRaw) ?? .capture }
        set { stageRaw = newValue.rawValue; touch() }
    }

    public var lensType: LensType? {
        get { lensTypeRaw.flatMap(LensType.init(rawValue:)) }
        set { lensTypeRaw = newValue?.rawValue; touch() }
    }

    public var origin: IdeaOrigin { IdeaOrigin(rawValue: originRaw) ?? .captured }

    public var pivotType: PivotType? {
        get { pivotTypeRaw.flatMap(PivotType.init(rawValue:)) }
        set { pivotTypeRaw = newValue?.rawValue }
    }

    public var isArchived: Bool { archivedAt != nil }

    /// Decision 0041: the idea's launch plan, if one was made. Stored as JSON
    /// so the plan's shape can grow without a schema change.
    public var launchPlanData: Data?

    public var launchPlan: LaunchPlan? {
        get { launchPlanData.flatMap { try? JSONDecoder().decode(LaunchPlan.self, from: $0) } }
        set { launchPlanData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    public var latestEvaluation: Evaluation? {
        evaluations.max { $0.version < $1.version }
    }

    public var latestRealityCheck: RealityCheck? {
        realityChecks.max { $0.createdAt < $1.createdAt }
    }

    public func touch() { updatedAt = Date() }

    public func archive() {
        archivedAt = Date()
        stage = .archived
        // Decision 0025: an archived idea's project leaves Reality with it. Launched stays launched.
        if let project, project.status == .active || project.status == .paused { project.status = .archived }
    }

    public func unarchive() {
        archivedAt = nil
        if stage == .archived { stage = .capture }
    }

    /// Starts a new, append-only evaluation version. Never mutates earlier versions.
    /// With `copying`, scores, evidence levels, notes, evidence links and the
    /// narrative fields carry forward so a re-evaluation starts where the last one ended.
    @discardableResult
    public func beginEvaluation(lens: LensType, copying previous: Evaluation? = nil) -> Evaluation {
        let next = (evaluations.map(\.version).max() ?? 0) + 1
        let evaluation = Evaluation(lens: lens, version: next)
        if let previous, previous.lensType == lens {
            for old in previous.criteria {
                let score = CriterionScore(key: old.key, score: old.score, evidenceLevel: old.evidenceLevel, note: old.note)
                score.peopleAtRung = old.peopleAtRung
                score.aiProposed = old.aiProposed
                score.deskLevel = old.deskLevel
                score.deskSourceCount = old.deskSourceCount
                for ev in old.evidence {
                    score.evidence.append(Evidence(criterionKey: ev.criterionKey, ladderRung: ev.ladderRung, text: ev.text, source: ev.source))
                }
                evaluation.criteria.append(score)
            }
            evaluation.riskiestAssumption = previous.riskiestAssumption
            evaluation.riskiestAssumptionConsequence = previous.riskiestAssumptionConsequence
            evaluation.recommendationRaw = previous.recommendationRaw
            evaluation.nextStepText = previous.nextStepText
            evaluation.projectionPricePerUnit = previous.projectionPricePerUnit
            evaluation.estimateInputs = previous.estimateInputs
            evaluation.projectionUnitsYearOne = previous.projectionUnitsYearOne
            evaluation.projectionRecurringPerMonth = previous.projectionRecurringPerMonth
            evaluation.impactWho = previous.impactWho
            evaluation.impactWhatChanges = previous.impactWhatChanges
            evaluation.impactSignal = previous.impactSignal
            evaluation.recompute()
        }
        evaluations.append(evaluation)
        if lensType == nil { lensTypeRaw = lens.rawValue }
        if stage == .capture || stage == .explore { stage = .evaluate }
        touch()
        return evaluation
    }

    /// First line of the raw text, trimmed, at most 60 characters.
    /// 2 to 5 words from the first clause of the person's words (ShortTitle).
    public static func suggestedTitle(from text: String) -> String {
        ShortTitle.make(from: text)
    }
}
