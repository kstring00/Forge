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
    public var evaluation: Evaluation?
    @Relationship(deleteRule: .cascade, inverse: \Evidence.criterionScore) public var evidence: [Evidence] = []

    public init(key: String, score: Int, evidenceLevel: Int, note: String = "") {
        self.key = key
        self.score = min(max(score, 1), 5)
        self.evidenceLevel = min(max(evidenceLevel, 0), 5)
        self.note = note
    }
}
