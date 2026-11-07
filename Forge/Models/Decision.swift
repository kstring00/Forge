import Foundation
import SwiftData
import ForgeCore

/// §5 Decision Journal. One entry per commitment, set-aside, ruling, pivot or
/// recorded outcome: what was decided, what was believed, why, and what
/// result was expected by when. Later, "what actually happened" is stored
/// next to the prediction. Shown only when the user opens the Journal.
///
/// Storage names `text`, `date` and `reason` predate v3 of the brief and are
/// kept so the store migrates lightly; the Journal vocabulary is exposed as
/// `decision`, `decidedAt` and `reasoning`.
@Model
public final class Decision {
    public var id: UUID = UUID()
    public var kindRaw: String = DecisionKind.commit.rawValue
    public var text: String = ""
    public var date: Date = Date()
    public var reason: String = ""
    public var beliefs: String = ""
    public var expectedResult: String = ""
    public var expectedBy: Date?
    public var actualResult: String?
    public var recordedAt: Date?
    public var idea: Idea?
    public var project: Project?
    public var ruling: Ruling?

    public init(kind: DecisionKind, decision: String, beliefs: String = "", reasoning: String = "",
                expectedResult: String = "", expectedBy: Date? = nil, decidedAt: Date = Date()) {
        self.kindRaw = kind.rawValue
        self.text = decision
        self.beliefs = beliefs
        self.reason = reasoning
        self.expectedResult = expectedResult
        self.expectedBy = expectedBy
        self.date = decidedAt
    }

    public var kind: DecisionKind {
        get { DecisionKind(rawValue: kindRaw) ?? .commit }
        set { kindRaw = newValue.rawValue }
    }

    public var decision: String {
        get { text }
        set { text = newValue }
    }

    public var decidedAt: Date {
        get { date }
        set { date = newValue }
    }

    public var reasoning: String {
        get { reason }
        set { reason = newValue }
    }

    public var hasOutcome: Bool { recordedAt != nil }

    /// Stores "what actually happened" next to the prediction. Never overwrites an earlier outcome.
    public func recordOutcome(_ result: String, at date: Date = Date()) {
        guard !hasOutcome else { return }
        actualResult = result
        recordedAt = date
    }
}
