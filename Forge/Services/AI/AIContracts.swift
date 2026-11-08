import Foundation
import ForgeCore

// Typed JSON contracts, one per action. The proxy validates the model's output
// against the same shapes. Nothing here is written to the store without a
// confirm step in the UI.

public struct ExpandResult: Codable, Sendable {
    public var proposedTitle: String?
    public var proposedSummary: String?
    public var clarifiedText: String
    public var openQuestions: [String]
}

public struct SummarizeResult: Codable, Sendable {
    public var notes: [String]
    public var decisions: [String]
    public var openQuestions: [String]
}

public struct ExperimentCard: Codable, Sendable {
    public var hypothesis: String
    public var test: String
    public var metric: String
    public var cost: String
    public var timeboxDays: Int
    public var decisionRule: String
}

public struct PlanResult: Codable, Sendable {
    public struct MilestonePlan: Codable, Sendable {
        public var title: String
        public var tasks: [String]
    }
    public var milestones: [MilestonePlan]
    public var firstDeliverable: String
}

public struct NextStepResult: Codable, Sendable {
    public var action: String
    public var why: String
}

public struct ExplainCriterionResult: Codable, Sendable {
    public var primer: String
    public var rulesForThisIdea: [String]
}

public struct CompareResult: Codable, Sendable {
    public struct CriterionComparison: Codable, Sendable {
        public var key: String
        public var leftNote: String
        public var rightNote: String
        public var edge: String   // "left" | "right" | "even"
    }
    public var lens: LensType
    public var comparisons: [CriterionComparison]
    public var verdict: String
}

public struct PivotResult: Codable, Sendable {
    public struct Variant: Codable, Sendable {
        public var pivotType: PivotType
        public var title: String
        public var body: String
        public var kept: String
        public var changed: String
        public var fixesCriterionKey: String
        public var newRiskiestAssumption: String
    }
    public var variants: [Variant]
}

public struct PitchResult: Codable, Sendable {
    public struct PitchDraft: Codable, Sendable {
        public var title: String
        public var body: String
        public var forWhom: String
        public var whyNow: String
        public var advantageUsed: String
        public var riskiestAssumption: String
        public var cluster: PitchCluster
        public var sphere: Sphere?
        /// Source IDs that back any demand claim. Empty means "assumption".
        public var groundedIn: [UUID]
    }
    public var pitches: [PitchDraft]
}

/// §6C. The proxy returns one verdict per Sphere and at most one crossfire reply per pair.
public struct RoundResult: Codable, Sendable {
    public struct VerdictDraft: Codable, Sendable {
        public var sphere: Sphere
        public var verdict: VerdictKind
        public var criterionKey: String
        public var reason: String
        public var sourceIDs: [UUID]
        public var evidenceNeeded: String?
    }
    public struct CrossfireDraft: Codable, Sendable {
        public var from: Sphere
        public var to: Sphere
        public var text: String
    }
    public var verdicts: [VerdictDraft]
    public var crossfire: [CrossfireDraft]
}

/// §6D. The proxy returns competitors, demand signals, the gap map and one verdict.
/// Every claim must point at a saved source ID; the app drops claims that don't.
public struct RealityCheckResult: Codable, Sendable {
    public struct CompetitorDraft: Codable, Sendable {
        public var name: String
        public var url: String?
        public var pricing: String
        public var positioning: String
        public var praises: [String]
        public var complaints: [String]
        public var tractionSignals: [String]
        public var sourceID: UUID?
    }
    public struct DemandSignalDraft: Codable, Sendable {
        public var text: String
        public var url: String?
        public var rung: Int
        public var sourceID: UUID?
    }
    public var verdict: RealityVerdict
    public var summary: String
    public var competitors: [CompetitorDraft]
    public var demandSignals: [DemandSignalDraft]
    public var gapMap: String
    public var fitNotes: String
    public var experiment: ExperimentCard?
    public var costEstimate: String
}

/// §0A. One typed object that pre-fills the whole Lab. Every field carries the
/// source IDs it leans on; the proxy has already clamped rungs to the desk
/// ceiling and turned source-less verdicts into cantTell. Everything here is
/// AI-found until the user touches it.
public struct PrefillResult: Codable, Sendable {
    public struct ExplorationDraft: Codable, Sendable {
        public var promptKey: String
        public var answer: String
        public var sourceIDs: [UUID]
    }
    public struct CriterionDraft: Codable, Sendable {
        public var key: String
        public var score: Int
        public var evidenceLevel: Int
        public var note: String
        public var sourceIDs: [UUID]
    }
    public struct ProjectionRange: Codable, Sendable {
        public var pricePerUnitLow: Double
        public var pricePerUnitHigh: Double
        public var unitsYearOneLow: Int
        public var unitsYearOneHigh: Int
        public var rationale: String
    }
    public struct RiskiestAssumptionDraft: Codable, Sendable {
        public var belief: String
        public var consequence: String
        public var sourceIDs: [UUID]
    }
    public struct NextMoveDraft: Codable, Sendable {
        public var recommendation: Recommendation
        public var step: String
        public var experiment: ExperimentCard?
    }
    public struct DraftedAssets: Codable, Sendable {
        public enum Kind: String, Codable, Sendable { case interviewQuestions, outreachScript, landingCopy }
        public var kind: Kind
        public var title: String
        public var body: String
    }
    public var realityCheck: RealityCheckResult
    public var explorations: [ExplorationDraft]
    public var criteria: [CriterionDraft]
    public var projection: ProjectionRange?
    /// The Investor's estimated return: a monthly USD range and what it rests on.
    /// Optional so an older proxy's answer still decodes.
    public var projectionLow: Double?
    public var projectionHigh: Double?
    public var projectionBasis: String?
    public var riskiestAssumption: RiskiestAssumptionDraft
    public var nextMove: NextMoveDraft
    public var draftedAssets: DraftedAssets
    public var panel: [RoundResult.VerdictDraft]
    public var crossfire: [RoundResult.CrossfireDraft]
}

/// Sugar so each action names its payload type in one place.
public extension AIAction {
    var payloadDescription: String {
        switch self {
        case .expand: "ExpandResult"
        case .runRound: "RoundResult"
        case .compare: "CompareResult"
        case .designExperiment: "ExperimentCard"
        case .plan: "PlanResult"
        case .nextStep: "NextStepResult"
        case .summarize: "SummarizeResult"
        case .explainCriterion: "ExplainCriterionResult"
        case .pivot: "PivotResult"
        case .pitch: "PitchResult"
        case .realityCheck: "RealityCheckResult"
        case .prefill: "PrefillResult"
        }
    }
}
