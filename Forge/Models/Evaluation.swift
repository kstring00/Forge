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

    public func score(for key: String) -> CriterionScore? {
        criteria.first { $0.key == key }
    }

    /// Sets or updates one criterion. Throws once the version is final.
    public func set(key: String, score: Int, evidenceLevel: Int, note: String = "") throws {
        guard !isFinal else { throw EvaluationError.alreadyFinal }
        if let existing = score(for: key) {
            existing.score = score
            existing.evidenceLevel = evidenceLevel
            existing.note = note
        } else {
            criteria.append(CriterionScore(key: key, score: score, evidenceLevel: evidenceLevel, note: note))
        }
        recompute()
    }

    /// Recomputes Potential, Confidence and shortfalls from the criteria.
    public func recompute() {
        guard !isFinal else { return }
        let ordered = lens.criteria.compactMap { score(for: $0.key) }
        potential = Scoring.potential(scores: ordered.map(\.score))
        confidence = Scoring.confidence(evidenceLevels: ordered.map(\.evidenceLevel))
        let scored = ordered.map {
            ScoredCriterion(key: $0.key, score: $0.score, evidenceLevel: $0.evidenceLevel, peopleAtRung: $0.peopleAtRung)
        }
        shortfallTexts = Shortfalls.compute(scored, lens: lens).map { "\($0.title): \($0.whatWouldHaveToBeTrue)" }
    }

    public func finalize() throws {
        guard !isFinal else { throw EvaluationError.alreadyFinal }
        recompute()
        finalizedAt = Date()
    }
}
