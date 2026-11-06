import Foundation

/// Pure scoring. No UI, no database.
///
/// Potential: criterion scores 1–5, equally weighted, mapped so that all-1s is 0
/// and all-5s is 100. A score of 1 means "I assume", and the honest display of
/// pure assumption is zero.
///
/// Confidence: evidence levels 0–5, equally weighted, mapped so that all-0s is 0
/// and all-5s is 100.
public enum Scoring {
    public static let scoreRange = 1...5
    public static let evidenceRange = 0...5

    public static func potential(scores: [Int]) -> Int {
        guard !scores.isEmpty else { return 0 }
        let clamped = scores.map { min(max($0, scoreRange.lowerBound), scoreRange.upperBound) }
        let mean = Double(clamped.reduce(0, +)) / Double(clamped.count)
        return normalize(mean, from: 1...5)
    }

    public static func confidence(evidenceLevels: [Int]) -> Int {
        guard !evidenceLevels.isEmpty else { return 0 }
        let clamped = evidenceLevels.map { min(max($0, evidenceRange.lowerBound), evidenceRange.upperBound) }
        let mean = Double(clamped.reduce(0, +)) / Double(clamped.count)
        return normalize(mean, from: 0...5)
    }

    /// Maps a value in `from` onto 0...100, rounded to nearest, clamped.
    public static func normalize(_ value: Double, from range: ClosedRange<Int>) -> Int {
        let lo = Double(range.lowerBound), hi = Double(range.upperBound)
        guard hi > lo else { return 0 }
        let t = (value - lo) / (hi - lo)
        return min(100, max(0, Int((t * 100).rounded())))
    }

    /// Below this, the UI shows "mostly enthusiasm so far, here's how to raise it."
    public static let lowConfidenceThreshold = 40

    public static func isMostlyEnthusiasm(confidence: Int) -> Bool {
        confidence < lowConfidenceThreshold
    }

    /// For A2 only: the score is the highest rung reached by at least
    /// `minimumPeople` independent people. Rungs 0 and 1 both yield a score of 1.
    public static func demandScore(peopleAtRung: [Int: Int], minimumPeople: Int = 3) -> Int {
        var best = 0
        for rung in 0...5 where (peopleAtRung[rung] ?? 0) >= minimumPeople {
            best = max(best, rung)
        }
        return max(1, best)
    }
}

/// How much of the Confidence rests on each source class. Percentages sum to
/// 100 when there is at least one item; all zero otherwise.
public struct ConfidenceBreakdown: Equatable, Sendable {
    public let verifiedPercent: Int
    public let aiFoundPercent: Int
    public let assumptionPercent: Int

    public init(classes: [SourceClass]) {
        guard !classes.isEmpty else {
            verifiedPercent = 0; aiFoundPercent = 0; assumptionPercent = 0
            return
        }
        let n = Double(classes.count)
        let v = classes.filter { $0 == .userVerified }.count
        let a = classes.filter { $0 == .aiFound }.count
        let s = classes.count - v - a
        var vp = Int((Double(v) / n * 100).rounded())
        let ap = Int((Double(a) / n * 100).rounded())
        let sp = Int((Double(s) / n * 100).rounded())
        // Absorb rounding drift into the largest bucket so the ring closes.
        let drift = 100 - (vp + ap + sp)
        if drift != 0 {
            if v >= a && v >= s { vp += drift }
            else if a >= s { verifiedPercent = vp; aiFoundPercent = ap + drift; assumptionPercent = sp; return }
            else { verifiedPercent = vp; aiFoundPercent = ap; assumptionPercent = sp + drift; return }
        }
        verifiedPercent = vp; aiFoundPercent = ap; assumptionPercent = sp
    }
}
