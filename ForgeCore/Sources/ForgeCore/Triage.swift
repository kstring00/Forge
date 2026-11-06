import Foundation

/// The shiny-object guard. Three or more "no" answers on the Opportunity Filter
/// and the app suggests exploring further or revisiting later before a full evaluation.
public struct TriageVerdict: Equatable, Sendable {
    public let noCount: Int
    public let unsureCount: Int
    public let answered: Int
    public let flagged: Bool
    public let suggestion: Recommendation?

    public static let flagThreshold = 3
}

public enum Triage {
    public static func evaluate(_ answers: [String: TriageAnswer]) -> TriageVerdict {
        let no = answers.values.filter { $0 == .no }.count
        let unsure = answers.values.filter { $0 == .unsure }.count
        let flagged = no >= TriageVerdict.flagThreshold
        // More "unsure" than "no" means the user lacks information: explore.
        // Otherwise the idea is known to be weak right now: revisit later.
        let suggestion: Recommendation? = flagged ? (unsure > no ? .exploreFurther : .revisitLater) : nil
        return TriageVerdict(noCount: no, unsureCount: unsure, answered: answers.count,
                             flagged: flagged, suggestion: suggestion)
    }
}
