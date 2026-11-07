import Foundation

/// The advisory next move. A suggestion rule the user can override; the
/// evaluation stores whatever the user chose.
public enum NextMove {
    /// Short label for the ember button: "Next move · Test it".
    public static func shortLabel(_ r: Recommendation) -> String {
        switch r {
        case .exploreFurther: "Explore"
        case .testRiskiestAssumption: "Test it"
        case .buildSmallPrototype: "Prototype"
        case .startBuilding: "Build"
        case .revisitLater: "Revisit"
        case .archive: "Archive"
        }
    }

    /// Suggests a move from the numbers. Confidence governs before Potential:
    /// a high score with no evidence is a hypothesis, not a plan.
    public static func suggest(potential: Int, confidence: Int, triageFlagged: Bool, scoredCount: Int, criteriaCount: Int) -> Recommendation {
        if scoredCount < criteriaCount { return .exploreFurther }
        if triageFlagged && confidence < Scoring.lowConfidenceThreshold { return .revisitLater }
        if potential < 35 { return .revisitLater }
        if confidence < Scoring.lowConfidenceThreshold { return .testRiskiestAssumption }
        if potential >= 70 && confidence >= 60 { return .startBuilding }
        if potential >= 55 { return .buildSmallPrototype }
        return .exploreFurther
    }

    /// One sentence shown under the move, for when the user has not written a step.
    public static func defaultStep(_ r: Recommendation, lens: Lens, lowestKey: String?) -> String {
        switch r {
        case .exploreFurther:
            return "Answer the Explore prompts you skipped, then score again."
        case .testRiskiestAssumption:
            if let key = lowestKey, let c = lens.criterion(key),
               let step = c.playbook.first(where: { $0.reachesRung >= 3 }) ?? c.playbook.first {
                return step.title
            }
            return "Design the cheapest test of the riskiest assumption."
        case .buildSmallPrototype:
            return "Write the smallest usable version in one paragraph, then build only that."
        case .startBuilding:
            return "Convert to a project and set the first next step."
        case .revisitLater:
            return "Set it aside with a note on what would bring you back."
        case .archive:
            return "Archive it with a sentence on why, so the Journal remembers."
        }
    }
}
