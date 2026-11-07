import Foundation
import SwiftData
import ForgeCore

public enum EvaluationError: Error, Equatable {
    case alreadyFinal
}

/// One evaluation version. Created through `Idea.beginEvaluation`, edited
/// until `finalize()`, then frozen. Earlier versions are never touched.
@Model
public final class Evaluation {
    public var id: UUID = UUID()
    public private(set) var version: Int = 1
    public var lensTypeRaw: String = LensType.business.rawValue
    public var createdAt: Date = Date()
    public private(set) var finalizedAt: Date?
    public private(set) var potential: Int = 0
    public private(set) var confidence: Int = 0
    public var shortfallTexts: [String] = []
    public var riskiestAssumption: String = ""
    public var recommendationRaw: String?

    // §4.0 Projection (Business lens) or Impact (Growth, Creative) card. All
    // user-entered, all optional, advisory only; never feeds Potential or Confidence.
    public var projectionPricePerUnit: Double?
    public var projectionUnitsYearOne: Int?
    public var projectionRecurringPerMonth: Double?
    public var impactWho: String?
    public var impactWhatChanges: String?
    public var impactSignal: String?

    /// "If wrong, …" under the riskiest assumption, and the concrete step shown
    /// on the Next move button. Both the user's words.
    public var riskiestAssumptionConsequence: String?
    public var nextStepText: String?

    /// §0A. Set when the Spheres pre-filled this version; cleared field by field
    /// as the user touches values. A projection range the AI suggested, shown
    /// as an estimate until the user accepts or edits it.
    public var aiFilledAt: Date?
    public var projectionSuggestion: String?

    public var idea: Idea?
    @Relationship(deleteRule: .cascade, inverse: \CriterionScore.evaluation) public var criteria: [CriterionScore] = []
    @Relationship(deleteRule: .cascade, inverse: \Experiment.evaluation) public var experiment: Experiment?

    public init(lens: LensType, version: Int) {
        self.lensTypeRaw = lens.rawValue
        self.version = version
    }

    public var lensType: LensType { LensType(rawValue: lensTypeRaw) ?? .business }
    public var lens: Lens { Lenses.lens(for: lensType) }
    public var isFinal: Bool { finalizedAt != nil }

    public var recommendation: Recommendation? {
        get { recommendationRaw.flatMap(Recommendation.init(rawValue:)) }
        set { recommendationRaw = newValue?.rawValue }
    }

    public func criterionScore(for key: String) -> CriterionScore? {
        criteria.first { $0.key == key }
    }

    /// Sets or updates one criterion. Throws once the version is final.
    public func set(key: String, score: Int, evidenceLevel: Int, note: String = "") throws {
        guard !isFinal else { throw EvaluationError.alreadyFinal }
        if let existing = criterionScore(for: key) {
            existing.score = score
            existing.evidenceLevel = evidenceLevel
            existing.note = note
            existing.aiProposed = false
        } else {
            criteria.append(CriterionScore(key: key, score: score, evidenceLevel: evidenceLevel, note: note))
        }
        recompute()
    }

    /// Recomputes Potential, Confidence and shortfalls from the criteria.
    public func recompute() {
        guard !isFinal else { return }
        let ordered = lens.criteria.compactMap { criterionScore(for: $0.key) }
        potential = Scoring.potential(scores: ordered.map(\.score))
        confidence = Scoring.confidence(evidenceLevels: ordered.map(\.evidenceLevel))
        let scored = ordered.map {
            ScoredCriterion(key: $0.key, score: $0.score, evidenceLevel: $0.evidenceLevel, peopleAtRung: $0.peopleAtRung)
        }
        shortfallTexts = Shortfalls.compute(scored, lens: lens).map { "\($0.title): \($0.whatWouldHaveToBeTrue)" }
    }

    /// Import only. Restores the computed fields of an evaluation rebuilt from
    /// an export. Refuses once this instance has been finalized here.
    func restore(potential: Int, confidence: Int, finalizedAt: Date?) {
        guard !isFinal else { return }
        self.potential = potential
        self.confidence = confidence
        self.finalizedAt = finalizedAt
    }

    public func finalize() throws {
        guard !isFinal else { throw EvaluationError.alreadyFinal }
        recompute()
        finalizedAt = Date()
    }
}
