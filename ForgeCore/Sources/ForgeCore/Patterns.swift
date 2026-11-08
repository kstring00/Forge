import Foundation

/// How a ruling turned out, once the user recorded what happened (§5).
public enum RulingOutcome: String, Codable, CaseIterable, Sendable {
    /// The Sphere's verdict held up.
    case sphereRight
    /// The user's position held up.
    case userRight
    /// What happened did not settle it.
    case unsettled

    public var displayName: String {
        switch self {
        case .sphereRight: "It was right"
        case .userRight: "You were right"
        case .unsettled: "Not settled"
        }
    }
}

/// One settled ruling, flattened for the patterns screen: who said what,
/// what the user ruled, how it turned out, and what the user had scored.
public struct SettledRuling: Equatable, Sendable {
    public var sphere: Sphere
    public var verdict: VerdictKind
    public var criterionKey: String
    public var choice: RulingChoice
    public var outcome: RulingOutcome
    /// The user's score on that criterion at the time, 1 to 5, if there was one.
    public var userScore: Int?

    public init(sphere: Sphere, verdict: VerdictKind, criterionKey: String, choice: RulingChoice, outcome: RulingOutcome, userScore: Int? = nil) {
        self.sphere = sphere
        self.verdict = verdict
        self.criterionKey = criterionKey
        self.choice = choice
        self.outcome = outcome
        self.userScore = userScore
    }
}

/// The user's record against the panel, computed from settled rulings. Shown
/// only once there are enough outcomes to say something; never a guess.
public struct Patterns: Equatable, Sendable {
    public struct SphereRecord: Equatable, Sendable {
        public let sphere: Sphere
        /// Times the user disagreed with this Sphere.
        public let overruled: Int
        /// Settled rulings where the Sphere turned out right.
        public let sphereRight: Int
        /// Settled rulings where the user turned out right.
        public let userRight: Int
        public var settled: Int { sphereRight + userRight }
    }

    public struct CriterionTendency: Equatable, Sendable {
        public let key: String
        /// Positive: the user scores it higher than outcomes bear out. Negative: lower.
        public let lean: Int
        public let cases: Int
    }

    /// The fewest recorded outcomes before anything is shown.
    public static let minimumOutcomes = 3

    public let outcomes: Int
    public let spheres: [SphereRecord]
    public let tendencies: [CriterionTendency]

    public var hasEnough: Bool { outcomes >= Patterns.minimumOutcomes }

    public init(_ rulings: [SettledRuling]) {
        let settled = rulings.filter { $0.outcome != .unsettled }
        outcomes = settled.count
        spheres = Sphere.phase3Panel.map { s in
            let mine = rulings.filter { $0.sphere == s }
            return SphereRecord(sphere: s,
                                overruled: mine.filter { $0.choice == .disagree }.count,
                                sphereRight: mine.filter { $0.outcome == .sphereRight }.count,
                                userRight: mine.filter { $0.outcome == .userRight }.count)
        }
        // A criterion the user scored high where an off-track verdict proved right
        // counts as over-scoring; scored low where on-track proved right, under-scoring.
        var byKey: [String: (lean: Int, cases: Int)] = [:]
        for r in settled {
            guard let score = r.userScore, r.outcome == .sphereRight else { continue }
            var entry = byKey[r.criterionKey] ?? (0, 0)
            if r.verdict == .offTrack && score >= 4 { entry.lean += 1; entry.cases += 1 }
            if r.verdict == .onTrack && score <= 2 { entry.lean -= 1; entry.cases += 1 }
            byKey[r.criterionKey] = entry
        }
        tendencies = byKey.filter { $0.value.cases > 0 }
            .map { CriterionTendency(key: $0.key, lean: $0.value.lean, cases: $0.value.cases) }
            .sorted { abs($0.lean) != abs($1.lean) ? abs($0.lean) > abs($1.lean) : $0.key < $1.key }
    }

    /// The Sphere the user is most often wrong to overrule, if any.
    public var mostUnderrated: SphereRecord? {
        spheres.filter { $0.overruled > 0 && $0.sphereRight > $0.userRight }.max { $0.sphereRight - $0.userRight < $1.sphereRight - $1.userRight }
    }

    /// The Sphere the user has most often been right against, if any.
    public var mostOverruledRightly: SphereRecord? {
        spheres.filter { $0.userRight > $0.sphereRight }.max { $0.userRight - $0.sphereRight < $1.userRight - $1.sphereRight }
    }

    /// Plain language, for the screen. Empty until there is enough.
    public func summary(lens: Lens) -> [String] {
        guard hasEnough else { return [] }
        var lines: [String] = []
        if let s = mostUnderrated {
            lines.append("When you overrule the \(s.sphere.displayName), it has been right \(s.sphereRight) of \(s.settled) times.")
        }
        if let s = mostOverruledRightly {
            lines.append("You have been right against the \(s.sphere.displayName) \(s.userRight) of \(s.settled) times.")
        }
        for t in tendencies.prefix(2) {
            let title = lens.criterion(t.key)?.title ?? t.key
            lines.append(t.lean > 0 ? "You tend to score \(title) higher than outcomes bear out." : "You tend to score \(title) lower than outcomes bear out.")
        }
        if lines.isEmpty { lines.append("\(outcomes) outcomes recorded; no pattern yet.") }
        return lines
    }

    /// The "about you" note the panel reads: under 80 words, from the record
    /// only. Empty until there is enough.
    public func aboutNote(lens: Lens) -> String {
        guard hasEnough else { return "" }
        var parts: [String] = ["\(outcomes) rulings settled so far."]
        if let s = mostUnderrated {
            parts.append("Tends to overrule the \(s.sphere.displayName) and be wrong (\(s.sphereRight) of \(s.settled)).")
        }
        if let s = mostOverruledRightly {
            parts.append("Has been right against the \(s.sphere.displayName) (\(s.userRight) of \(s.settled)).")
        }
        if let t = tendencies.first {
            let title = lens.criterion(t.key)?.title ?? t.key
            parts.append(t.lean > 0 ? "Scores \(title) high; outcomes say lower." : "Scores \(title) low; outcomes say higher.")
        }
        var note = parts.joined(separator: " ")
        // Hard cap at 80 words.
        let words = note.split(separator: " ")
        if words.count > 80 { note = words.prefix(80).joined(separator: " ") }
        return note
    }
}
