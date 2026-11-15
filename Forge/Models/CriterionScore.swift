import Foundation
import SwiftData
import ForgeCore

@Model
public final class CriterionScore {
    public var id: UUID = UUID()
    public var key: String = ""
    public var score: Int = 1
    public var evidenceLevel: Int = 0
    public var note: String = ""
    /// For A2: independent people counted at `evidenceLevel`.
    public var peopleAtRung: Int = 0
    /// True while this score is the Spheres' proposal; false once the user picks an anchor or rung.
    public var aiProposed: Bool = false
    /// Decision 0037: the graded desk level (1.0 to 2.0) from the number and rank of independent sources.
    public var deskLevel: Double?
    public var deskSourceCount: Int = 0
    public var evaluation: Evaluation?
    @Relationship(deleteRule: .cascade, inverse: \Evidence.criterionScore) public var evidence: [Evidence] = []

    public init(key: String, score: Int, evidenceLevel: Int, note: String = "") {
        self.key = key
        self.score = min(max(score, 1), 5)
        self.evidenceLevel = min(max(evidenceLevel, 0), 5)
        self.note = note
    }

    /// What counts toward how sure we are: lived evidence (3 and up) always;
    /// otherwise the graded desk level while it is the panel's proposal; the
    /// person's own pick once they touch it.
    public var effectiveLevel: Double {
        if evidenceLevel >= 3 { return Double(evidenceLevel) }
        if aiProposed, let deskLevel { return deskLevel }
        return Double(evidenceLevel)
    }
}
