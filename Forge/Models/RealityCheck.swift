import Foundation
import SwiftData
import ForgeCore

/// One demand signal found by desk research, tagged with the rung it supports.
/// Desk research never exceeds rung 2.
public struct DemandSignal: Codable, Hashable, Sendable {
    public var text: String
    public var url: String?
    public var rung: Int
    public var sourceID: UUID?

    public init(text: String, url: String? = nil, rung: Int, sourceID: UUID? = nil) {
        self.text = text
        self.url = url
        self.rung = min(max(rung, 0), Scoring.deskResearchRungCeiling)
        self.sourceID = sourceID
    }
}

/// One "What if…" the Strategist offered with the Brief (decision 0024). Saved
/// on the check; becomes its own idea only when the user says so.
public struct PivotIdea: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var whatIf: String
    public var pivotTypeRaw: String
    /// The criterion key the change raises.
    public var fixes: String
    public var why: String
    public var firstTest: String
    public var sourceIDs: [UUID]
    /// The idea made from it, once "Make this its own idea" was tapped.
    public var spawnedIdeaID: UUID?

    public init(id: UUID = UUID(), whatIf: String, pivotType: PivotType, fixes: String, why: String, firstTest: String, sourceIDs: [UUID] = [], spawnedIdeaID: UUID? = nil) {
        self.id = id
        self.whatIf = whatIf
        self.pivotTypeRaw = pivotType.rawValue
        self.fixes = fixes
        self.why = why
        self.firstTest = firstTest
        self.sourceIDs = sourceIDs
        self.spawnedIdeaID = spawnedIdeaID
    }

    public var pivotType: PivotType { PivotType(rawValue: pivotTypeRaw) ?? .zoomIn }
}

/// §6D. A desk-research report on a Business-lens idea ending in one of four
/// advisory verdicts. Every claim cites a saved Source; the user's own
/// Decision, not the verdict, is what the app later checks against reality.
@Model
public final class RealityCheck {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var verdictRaw: String = RealityVerdict.cantTell.rawValue
    public var demandSignals: [DemandSignal] = []
    public var gapMap: String = ""
    public var fitNotes: String = ""
    public var limitsNote: String = RealityCheck.standardLimitsNote
    public var costEstimate: String = ""
    public var summary: String = ""
    /// The panel's three-sentence rationale and the actual cost once known.
    public var rationale: String?
    public var actualCostUSD: Double?
    /// Findings the panel offered without a source, left out rather than shown as fact.
    public var droppedFindings: Int = 0
    /// "What if…" pivots offered with this check (decision 0024).
    public var pivots: [PivotIdea] = []
    /// The drafted asset (interview questions, outreach script, landing copy) saved as a Source.
    public var draftedAssetSourceID: UUID?
    public var idea: Idea?
    public var sources: [Source] = []
    @Relationship(deleteRule: .cascade, inverse: \Competitor.realityCheck) public var competitors: [Competitor] = []
    @Relationship(deleteRule: .cascade, inverse: \Experiment.realityCheck) public var experiment: Experiment?

    public init(verdict: RealityVerdict, summary: String = "", costEstimate: String = "") {
        self.verdictRaw = verdict.rawValue
        self.summary = summary
        self.costEstimate = costEstimate
    }

    public var verdict: RealityVerdict {
        get { RealityVerdict(rawValue: verdictRaw) ?? .cantTell }
        set { verdictRaw = newValue.rawValue }
    }

    /// Shown in every report, in plain words.
    public static let standardLimitsNote = "Desk research can prove the problem and the market exist (rung 2 on the evidence ladder). It cannot prove anyone will give you time or money for this angle. Rungs 3 to 5 need a real person outside the app."
}
