import Foundation
import ForgeCore

/// Lab helpers over an evaluation. Pure reads; no UI.
extension Evaluation {
    var scoredCount: Int { lens.criteria.filter { criterionScore(for: $0.key) != nil }.count }
    var isComplete: Bool { scoredCount == lens.criteria.count }

    /// Every evidence item on this version. Items with no source count as assumptions.
    var allEvidence: [Evidence] { criteria.flatMap(\.evidence) }

    var confidenceBreakdown: ConfidenceBreakdown {
        ConfidenceBreakdown(classes: allEvidence.map { $0.source?.sourceClass ?? .assumption })
    }

    /// The pattern on a criterion row: solid if any counted evidence is verified,
    /// stripes if the best is a reviewed or unreviewed AI find, dots otherwise.
    func pattern(for key: String) -> EvidencePattern {
        let classes = (criterionScore(for: key)?.evidence ?? []).map { $0.source?.sourceClass ?? .assumption }
        if classes.contains(.userVerified) { return .solid }
        if classes.contains(.aiFound) { return .stripes }
        return .dots
    }

    /// §4.0. Units are verified only by a real payment: evidence at rung 4 or
    /// above whose source counts toward Confidence.
    var projection: Projection {
        let paid = allEvidence.filter { $0.ladderRung >= 4 && $0.countsTowardConfidence }.count
        return Projection(pricePerUnit: projectionPricePerUnit, unitsYearOne: projectionUnitsYearOne, verifiedUnits: paid)
    }

    /// The weakest scored criterion. On a tie under the Business lens, Demand
    /// evidence wins: it is the criterion most often faked by enthusiasm.
    var lowestKey: String? {
        let scored = lens.criteria.compactMap { c in criterionScore(for: c.key).map { (c.key, $0.score) } }
        guard let minScore = scored.map(\.1).min() else { return nil }
        let ties = scored.filter { $0.1 == minScore }.map(\.0)
        if lensType == .business, ties.contains("A2") { return "A2" }
        return ties.first
    }

    /// The criterion whose ladder the summary shows: A2 for Business, else the lowest scored.
    var ladderKey: String {
        lensType == .business ? "A2" : (lowestKey ?? lens.criteria[0].key)
    }

    func suggestedMove(triageFlagged: Bool) -> Recommendation {
        NextMove.suggest(potential: potential, confidence: confidence, triageFlagged: triageFlagged,
                         scoredCount: scoredCount, criteriaCount: lens.criteria.count)
    }

    var effectiveMove: Recommendation {
        recommendation ?? suggestedMove(triageFlagged: idea?.triage?.verdict.flagged ?? false)
    }

    var effectiveStep: String {
        let t = (nextStepText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? NextMove.defaultStep(effectiveMove, lens: lens, lowestKey: lowestKey) : t
    }
}
