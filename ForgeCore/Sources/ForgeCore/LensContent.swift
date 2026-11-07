import Foundation

// The shape of lens content. Every criterion in every lens fills this shape,
// and `LensContentIntegrityTests` fails the build's test run if any field is
// empty. UI code reads these types; it never contains teaching text itself.

public struct Framework: Hashable, Sendable {
    public let name: String
    public let author: String
    /// One line on what the framework contributes to this lens.
    public let note: String

    public init(name: String, author: String, note: String) {
        self.name = name
        self.author = author
        self.note = note
    }
}

public extension Framework {
    static let momTest = Framework(
        name: "The Mom Test", author: "Rob Fitzpatrick",
        note: "Ask about past behaviour, never pitch. Compliments are not data.")
    static let leanStartup = Framework(
        name: "The Lean Startup", author: "Eric Ries",
        note: "An idea is a hypothesis until a measurable behaviour confirms it.")
    static let hundredMOffers = Framework(
        name: "$100M Offers", author: "Alex Hormozi",
        note: "Value = (dream outcome × likelihood) ÷ (time delay × effort).")
    static let hundredMLeads = Framework(
        name: "$100M Leads", author: "Alex Hormozi",
        note: "A product nobody finds is not a business. Name the channel.")
    static let blueOcean = Framework(
        name: "Blue Ocean Strategy", author: "W. Chan Kim & Renée Mauborgne",
        note: "Eliminate, reduce, raise, create: draw a different value curve.")
    static let goodStrategy = Framework(
        name: "Good Strategy / Bad Strategy", author: "Richard Rumelt",
        note: "Diagnosis, guiding policy, coherent action. Use an existing advantage.")
    static let twelveMonths = Framework(
        name: "12 Months to $1 Million", author: "Ryan Daniel Moran",
        note: "Pick a person, serve them with a first product, then widen.")
    static let eMyth = Framework(
        name: "The E-Myth Revisited", author: "Michael E. Gerber",
        note: "If it only works while you do custom labour, you built a job.")
    static let profitFirst = Framework(
        name: "Profit First", author: "Mike Michalowicz",
        note: "Does the money work from the first sale, not someday?")
    static let atomicHabits = Framework(
        name: "Atomic Habits", author: "James Clear",
        note: "Identity first, then the smallest version you would never skip.")
    static let deepWork = Framework(
        name: "Deep Work", author: "Cal Newport",
        note: "Skills that compound need protected, focused time.")
    static let valuesAlignment = Framework(
        name: "Values alignment", author: "general practice",
        note: "Does this match who you are becoming, or only what sounds impressive?")
    static let buildMeasureLearn = Framework(
        name: "Build, measure, learn", author: "Eric Ries, applied to play",
        note: "Make the smallest thing first. Judge it after, not before.")
}

/// Anchored descriptions of what a score looks like. 1, 3 and 5 are required;
/// 2 and 4 are optional and shown when present.
public struct Rubric: Sendable {
    public let anchors: [Int: String]

    public init(_ anchors: [Int: String]) {
        self.anchors = anchors
    }

    public func anchor(for score: Int) -> String? { anchors[score] }

    /// The nearest anchor at or below `score`, for scores without their own text.
    public func nearestAnchor(for score: Int) -> String {
        var s = score
        while s >= 1 {
            if let a = anchors[s] { return a }
            s -= 1
        }
        return anchors[1] ?? ""
    }
}

/// One rung on a criterion's evidence ladder. Levels run 0 through 5.
public struct LadderRung: Identifiable, Sendable {
    public let level: Int
    public let label: String
    public let description: String
    /// What this rung is worth, said plainly.
    public let worth: String

    public var id: Int { level }

    public init(_ level: Int, _ label: String, description: String, worth: String) {
        self.level = level
        self.label = label
        self.description = description
        self.worth = worth
    }
}

/// A concrete thing to go do this week to get evidence for a criterion.
public struct PlaybookStep: Identifiable, Sendable {
    public let title: String
    public let body: String
    /// The highest ladder rung this step can reach.
    public let reachesRung: Int
    /// Rough effort in words: "an hour", "this week", "two to four weeks".
    public let effort: String

    public var id: String { title }

    public init(_ title: String, _ body: String, reachesRung: Int, effort: String) {
        self.title = title
        self.body = body
        self.reachesRung = reachesRung
        self.effort = effort
    }
}

public struct Criterion: Identifiable, Sendable {
    public let key: String
    public let title: String
    public let alias: String?
    public let frameworks: [Framework]
    public let definition: String
    public let rubric: Rubric
    public let ladder: [LadderRung]
    public let doesNotCount: [String]
    public let playbook: [PlaybookStep]
    /// Phrased with `{rung}`, `{count}` and `{next}` placeholders. See `Shortfalls`.
    public let shortfallTemplate: String
    public let aiBoundary: String
    /// When true the rubric score is the ladder rung (A2 only).
    public let scoreEqualsLadder: Bool

    public var id: String { key }

    public init(
        key: String, title: String, alias: String? = nil,
        frameworks: [Framework], definition: String, rubric: Rubric,
        ladder: [LadderRung], doesNotCount: [String], playbook: [PlaybookStep],
        shortfallTemplate: String, aiBoundary: String, scoreEqualsLadder: Bool = false
    ) {
        self.key = key
        self.title = title
        self.alias = alias
        self.frameworks = frameworks
        self.definition = definition
        self.rubric = rubric
        self.ladder = ladder
        self.doesNotCount = doesNotCount
        self.playbook = playbook
        self.shortfallTemplate = shortfallTemplate
        self.aiBoundary = aiBoundary
        self.scoreEqualsLadder = scoreEqualsLadder
    }

    public func rung(_ level: Int) -> LadderRung? {
        ladder.first { $0.level == level }
    }
}

public struct Lens: Identifiable, Sendable {
    public let type: LensType
    public let tagline: String
    public let frameworks: [Framework]
    public let criteria: [Criterion]
    /// What Confidence means under this lens, in one sentence.
    public let confidenceNote: String

    public var id: LensType { type }
    public var name: String { type.displayName }

    public init(type: LensType, tagline: String, frameworks: [Framework],
                criteria: [Criterion], confidenceNote: String) {
        self.type = type
        self.tagline = tagline
        self.frameworks = frameworks
        self.criteria = criteria
        self.confidenceNote = confidenceNote
    }

    public func criterion(_ key: String) -> Criterion? {
        criteria.first { $0.key == key }
    }
}
