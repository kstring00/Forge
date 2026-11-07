import Foundation
import SwiftData
import ForgeCore

/// The 60-second triage. Answers keyed by `OpportunityFilterQuestions` keys.
@Model
public final class OpportunityFilter {
    public var id: UUID = UUID()
    public var answersRaw: [String: String] = [:]
    public var completedAt: Date?
    public var idea: Idea?

    public init() {}

    public var answers: [String: TriageAnswer] {
        get { answersRaw.compactMapValues(TriageAnswer.init(rawValue:)) }
        set { answersRaw = newValue.mapValues(\.rawValue) }
    }

    public func answer(_ key: String, _ value: TriageAnswer) {
        answersRaw[key] = value.rawValue
        if answersRaw.count >= OpportunityFilterQuestions.all.count { completedAt = Date() }
    }

    public var verdict: TriageVerdict { Triage.evaluate(answers) }
    public var isComplete: Bool { completedAt != nil }
}
