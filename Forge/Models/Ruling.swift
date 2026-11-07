import Foundation
import SwiftData
import ForgeCore

/// §6C. The user's ruling on one verdict and what it produced.
/// Agree → Decision, or Evidence if the Sphere cited a source.
/// Disagree → an Assumption source holding the user's belief.
/// Find out → Experiment card.
@Model
public final class Ruling {
    public var id: UUID = UUID()
    public var choiceRaw: String = RulingChoice.findOut.rawValue
    public var note: String?
    public var createdAt: Date = Date()
    public var verdict: Verdict?
    @Relationship(deleteRule: .nullify, inverse: \Decision.ruling) public var resultingDecision: Decision?
    public var resultingEvidence: Evidence?
    public var resultingAssumption: Source?
    @Relationship(deleteRule: .nullify, inverse: \Experiment.ruling) public var resultingExperiment: Experiment?

    public init(choice: RulingChoice, note: String? = nil) {
        self.choiceRaw = choice.rawValue
        self.note = note
    }

    public var choice: RulingChoice { RulingChoice(rawValue: choiceRaw) ?? .findOut }
}
