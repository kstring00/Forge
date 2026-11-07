import Foundation

/// A scored criterion as the Domain layer sees it. The SwiftData model maps to this.
public struct ScoredCriterion: Hashable, Sendable {
    public let key: String
    public let score: Int
    public let evidenceLevel: Int
    /// For A2: independent people counted at the current rung.
    public let peopleAtRung: Int

    public init(key: String, score: Int, evidenceLevel: Int, peopleAtRung: Int = 0) {
        self.key = key
        self.score = score
        self.evidenceLevel = evidenceLevel
        self.peopleAtRung = peopleAtRung
    }
}

/// "Where it falls short", in words, with what would have to be true to raise it.
public struct Shortfall: Identifiable, Sendable {
    public let criterionKey: String
    public let title: String
    public let score: Int
    public let whatWouldHaveToBeTrue: String
    public let suggestedStep: PlaybookStep?

    public var id: String { criterionKey }
}

public enum Shortfalls {
    /// Criteria scoring 2 or below. If none, the lowest two. Lowest first.
    public static func compute(_ scored: [ScoredCriterion], lens: Lens) -> [Shortfall] {
        guard !scored.isEmpty else { return [] }
        let sorted = scored.sorted { ($0.score, $0.key) < ($1.score, $1.key) }
        let low = sorted.filter { $0.score <= 2 }
        let picked = low.isEmpty ? Array(sorted.prefix(2)) : low
        return picked.compactMap { sc in
            guard let c = lens.criterion(sc.key) else { return nil }
            let nextScore = min(sc.score + 1, 5)
            let nextAnchor = c.rubric.nearestAnchor(for: nextScore)
            let step = cheapestStep(reaching: sc.evidenceLevel + 1, in: c)
            let text = fill(c.shortfallTemplate,
                            rung: sc.evidenceLevel, count: sc.peopleAtRung,
                            next: min(sc.evidenceLevel + 1, 5), step: step)
            return Shortfall(
                criterionKey: c.key,
                title: c.title,
                score: sc.score,
                whatWouldHaveToBeTrue: "To score \(nextScore): \(nextAnchor)\n\(text)",
                suggestedStep: step)
        }
    }

    /// The first playbook step (they are ordered cheapest first) that reaches `rung`.
    public static func cheapestStep(reaching rung: Int, in criterion: Criterion) -> PlaybookStep? {
        criterion.playbook.first { $0.reachesRung >= rung }
            ?? criterion.playbook.last
    }

    static func fill(_ template: String, rung: Int, count: Int, next: Int, step: PlaybookStep?) -> String {
        template
            .replacingOccurrences(of: "{rung}", with: String(rung))
            .replacingOccurrences(of: "{count}", with: String(count))
            .replacingOccurrences(of: "{next}", with: String(next))
            .replacingOccurrences(of: "{step}", with: step.map { lowercaseFirst($0.title) } ?? "gather more evidence")
    }

    static func lowercaseFirst(_ s: String) -> String {
        guard let f = s.first else { return s }
        return f.lowercased() + s.dropFirst()
    }
}
