import Foundation

/// One guided-thinking prompt. A Sphere may ask it, so the exploration stage
/// already carries the panel's angles (brief §6C, "Spheres elsewhere").
public struct ExplorePrompt: Identifiable, Sendable {
    public let key: String
    public let question: String
    public let hint: String
    public let sphere: Sphere?

    public var id: String { key }

    public init(key: String, question: String, hint: String, sphere: Sphere?) {
        self.key = key
        self.question = question
        self.hint = hint
        self.sphere = sphere
    }
}

public enum ExplorePrompts {
    public static let all: [ExplorePrompt] = [
        ExplorePrompt(key: "problem",
                      question: "What problem does this solve?",
                      hint: "Describe it the way the person who has it would, not the way you'd pitch it.",
                      sphere: .customer),
        ExplorePrompt(key: "who",
                      question: "Who has this problem, specifically?",
                      hint: "A name, or a kind of person you could actually find this week.",
                      sphere: .customer),
        ExplorePrompt(key: "today",
                      question: "What do they do about it today?",
                      hint: "A spreadsheet, a workaround, paying someone, nothing. Nothing is an answer.",
                      sphere: .customer),
        ExplorePrompt(key: "why",
                      question: "Why does this interest you?",
                      hint: "The honest answer. Money, curiosity, a grudge, a skill you want.",
                      sphere: .steward),
        ExplorePrompt(key: "tiny",
                      question: "What does the tiniest version look like?",
                      hint: "Something you could put in front of one person within a week.",
                      sphere: .builder),
        ExplorePrompt(key: "kills",
                      question: "What would kill it?",
                      hint: "The one thing that, if true, means you should stop.",
                      sphere: .skeptic)
    ]

    public static let keys: [String] = all.map(\.key)

    public static func prompt(for key: String) -> ExplorePrompt? {
        all.first { $0.key == key }
    }

    /// Explorations written by the AI (and confirmed by the user) use these keys.
    public static let aiKeyPrefix = "ai."

    public static func isAIKey(_ key: String) -> Bool { key.hasPrefix(aiKeyPrefix) }

    public static func aiLabel(for key: String) -> String {
        switch key {
        case "ai.expand": "Clarified"
        case "ai.openQuestions": "Open questions"
        case "ai.summary": "Summary"
        case "ai.summary.notes": "Notes"
        case "ai.summary.decisions": "Decisions"
        case "ai.summary.openQuestions": "Open questions"
        default: key.replacingOccurrences(of: aiKeyPrefix, with: "").capitalized
        }
    }
}
