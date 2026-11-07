import Foundation
import SwiftData

/// §6C. One panel session on an idea: pitch, verdicts, crossfire, rulings, summary.
/// Saved in full so a later Round can be diffed against it.
@Model
public final class Round {
    public var id: UUID = UUID()
    public var pitchText: String = ""
    public var createdAt: Date = Date()
    public var summary: String?
    public var idea: Idea?
    @Relationship(deleteRule: .cascade, inverse: \Verdict.round) public var verdicts: [Verdict] = []
    @Relationship(deleteRule: .cascade, inverse: \Crossfire.round) public var crossfire: [Crossfire] = []

    public init(pitchText: String) {
        self.pitchText = pitchText
    }

    public var rulings: [Ruling] { verdicts.compactMap(\.ruling) }
    public var isRuled: Bool { !verdicts.isEmpty && verdicts.allSatisfy { $0.ruling != nil } }
}
