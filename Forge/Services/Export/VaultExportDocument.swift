import Foundation
import ForgeCore

// The on-disk shape of a Vault export: plain Codable, versioned, no SwiftData.
// Enum values are stored as their raw strings so the file stays readable and
// stable even if Swift names change. Every ID is preserved so a re-import is
// idempotent and relationships survive.

struct VaultExportDocument: Codable {
    static let currentSchemaVersion = 1
    static let fileName = "vault.json"
    static let markdownFileName = "vault.md"
    static let recordingsFolder = "recordings"

    var schemaVersion: Int = VaultExportDocument.currentSchemaVersion
    var app: String = "FORGE"
    var exportedAt: Date
    var ideas: [IdeaExport]
    var decisions: [DecisionExport]
    var pitches: [PitchExport]
    var advantages: [AdvantageExport]
    var constraints: [ConstraintExport]
    var stewardCharter: String?
}

struct IdeaExport: Codable {
    var id: UUID
    var title: String
    var originalText: String
    var aiSummary: String?
    var aiSummaryConfirmed: Bool
    var lensType: String?
    var stage: String
    var tags: [String]
    var notes: String
    var createdAt: Date
    var updatedAt: Date
    var archivedAt: Date?
    var origin: String
    var pivotType: String?
    var pivotOfID: UUID?
    var audioFileName: String?
    var triage: TriageExport?
    var explorations: [ExplorationExport]
    var evaluations: [EvaluationExport]
    var sources: [SourceExport]
    var artifacts: [ArtifactExport]
    var rounds: [RoundExport]
    var realityChecks: [RealityCheckExport]
    var project: ProjectExport?
}

struct TriageExport: Codable {
    var id: UUID
    var answers: [String: String]
    var completedAt: Date?
}

struct ExplorationExport: Codable {
    var id: UUID
    var createdAt: Date
    var promptKey: String
    var userText: String
    var aiText: String?
    var confirmed: Bool
}

struct EvaluationExport: Codable {
    var id: UUID
    var version: Int
    var lensType: String
    var createdAt: Date
    var finalizedAt: Date?
    var potential: Int
    var confidence: Int
    var shortfallTexts: [String]
    var riskiestAssumption: String
    var recommendation: String?
    var projectionPricePerUnit: Double?
    var projectionUnitsYearOne: Int?
    var projectionRecurringPerMonth: Double?
    var impactWho: String?
    var impactWhatChanges: String?
    var impactSignal: String?
    var riskiestAssumptionConsequence: String?
    var nextStepText: String?
    var aiFilledAt: Date?
    var projectionSuggestion: String?
    var projectionEstimateLow: Double?
    var projectionEstimateHigh: Double?
    var projectionEstimateBasis: String?
    var criteria: [CriterionScoreExport]
    var experiment: ExperimentExport?
}

struct CriterionScoreExport: Codable {
    var id: UUID
    var key: String
    var score: Int
    var evidenceLevel: Int
    var note: String
    var peopleAtRung: Int
    var aiProposed: Bool?
    var evidence: [EvidenceExport]
}

struct EvidenceExport: Codable {
    var id: UUID
    var criterionKey: String
    var ladderRung: Int
    var text: String
    var createdAt: Date
    var sourceID: UUID?
}

struct ExperimentExport: Codable {
    var id: UUID
    var hypothesis: String
    var test: String
    var metric: String
    var cost: String
    var timeboxDays: Int
    var decisionRule: String
    var outcome: String?
    var createdAt: Date
}

struct SourceExport: Codable {
    var id: UUID
    var kind: String
    var title: String
    var url: String?
    var fileRef: String?
    var fullText: String
    var aiSummary: String?
    var sourceClass: String
    var reviewed: Bool
    var capturedAt: Date
    var chunks: [ChunkExport]
}

struct ChunkExport: Codable {
    var id: UUID
    var index: Int
    var text: String
}

struct ArtifactExport: Codable {
    var id: UUID
    var kind: String
    var content: String
    var audioRef: String?
    var createdAt: Date
}

struct RoundExport: Codable {
    var id: UUID
    var pitchText: String
    var createdAt: Date
    var summary: String?
    var verdicts: [VerdictExport]
    var crossfire: [CrossfireExport]
}

struct VerdictExport: Codable {
    var id: UUID
    var sphere: String
    var kind: String
    var criterionKey: String
    var reason: String
    var evidenceNeeded: String?
    var sourceIDs: [UUID]
    var ruling: RulingExport?
}

struct RulingExport: Codable {
    var id: UUID
    var choice: String
    var note: String?
    var createdAt: Date
    var resultingDecisionID: UUID?
    var resultingEvidenceID: UUID?
    var resultingAssumptionID: UUID?
    var resultingExperiment: ExperimentExport?
    // v4.2: implicit agrees and outcomes. Optional so old exports import.
    var implicit: Bool?
    var outcome: String?
    var outcomeNote: String?
    var outcomeRecordedAt: Date?
}

struct CrossfireExport: Codable {
    var id: UUID
    var fromSphere: String
    var toSphere: String
    var text: String
}

struct RealityCheckExport: Codable {
    var id: UUID
    var createdAt: Date
    var verdict: String
    var summary: String
    var demandSignals: [DemandSignal]
    var gapMap: String
    var fitNotes: String
    var limitsNote: String
    var costEstimate: String
    var rationale: String?
    var actualCostUSD: Double?
    var droppedFindings: Int?
    var draftedAssetSourceID: UUID?
    var sourceIDs: [UUID]
    var competitors: [CompetitorExport]
    var experiment: ExperimentExport?
}

struct CompetitorExport: Codable {
    var id: UUID
    var name: String
    var url: String?
    var pricing: String
    var positioning: String
    var praises: [String]
    var complaints: [String]
    var tractionSignals: [String]
    var fetchedAt: Date
    var sourceID: UUID?
}

struct ProjectExport: Codable {
    var id: UUID
    var name: String
    var projectDescription: String
    var desiredOutcome: String
    var status: String
    var notes: [String]
    var resources: [String]
    var nextStep: String?
    var launchDefinition: String
    var retrospective: String?
    var createdAt: Date
    var pausedAt: Date?
    var completedAt: Date?
    var milestones: [MilestoneExport]
    // v4.2: the next step's caveat, count and due date. Optional so old exports import.
    var nextStepCaveat: String?
    var nextStepTarget: Int?
    var nextStepCount: Int?
    var nextStepDueAt: Date?
    var nextStepMoves: String?
}

struct MilestoneExport: Codable {
    var id: UUID
    var title: String
    var order: Int
    var done: Bool
    var tasks: [TaskExport]
}

struct TaskExport: Codable {
    var id: UUID
    var title: String
    var done: Bool
    var createdAt: Date
    var completedAt: Date?
}

/// Decisions are top-level because one may belong to an idea, a project, or both.
struct DecisionExport: Codable {
    var id: UUID
    var kind: String
    var decision: String
    var decidedAt: Date
    var beliefs: String
    var reasoning: String
    var expectedResult: String
    var expectedBy: Date?
    var actualResult: String?
    var recordedAt: Date?
    var ideaID: UUID?
    var projectID: UUID?
}

struct PitchExport: Codable {
    var id: UUID
    var title: String
    var body: String
    var forWhom: String
    var whyNow: String
    var advantageUsed: String
    var riskiestAssumption: String
    var cluster: String
    var sphere: String?
    var createdAt: Date
    var status: String
    var rejectionReason: String?
    var savedIdeaID: UUID?
}

struct AdvantageExport: Codable {
    var id: UUID
    var text: String
    var kind: String
    var createdAt: Date
}

struct ConstraintExport: Codable {
    var id: UUID
    var text: String
    var createdAt: Date
    var fromPitchID: UUID?
}
