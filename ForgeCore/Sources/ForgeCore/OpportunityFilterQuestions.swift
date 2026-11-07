import Foundation

/// The 60-second triage shown before a full evaluation. Not scored; it surfaces red flags.
public struct FilterQuestion: Identifiable, Sendable {
    public let key: String
    public let text: String
    public var id: String { key }
}

public enum OpportunityFilterQuestions {
    public static let all: [FilterQuestion] = [
        FilterQuestion(key: "advantage", text: "Does it use an advantage I already have?"),
        FilterQuestion(key: "reach", text: "Can I actually reach the people it's for?"),
        FilterQuestion(key: "realProblem", text: "Is the problem real, or did I invent it?"),
        FilterQuestion(key: "testable", text: "Can I test demand in under two weeks?"),
        FilterQuestion(key: "income", text: "Could it produce income?"),
        FilterQuestion(key: "recurring", text: "Could that income recur?"),
        FilterQuestion(key: "asset", text: "Does it create an asset that outlives the work?"),
        FilterQuestion(key: "learning", text: "Does it teach me something I want to learn?"),
        FilterQuestion(key: "reputation", text: "Does it strengthen my reputation?"),
        FilterQuestion(key: "opportunityCost", text: "Is this better than what I'd otherwise be working on?")
    ]

    public static let keys: [String] = all.map(\.key)
}
