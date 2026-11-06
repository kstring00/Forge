import Foundation
import SwiftData
import ForgeCore

/// A captured idea. `originalText` is set once, in `init`, and has no setter
/// outside this class. Everything else may change; the raw thought never does.
@Model
public final class Idea {
    public var id: UUID = UUID()
    public var title: String = ""
    public private(set) var originalText: String = ""
    public var aiSummary: String?
    public var aiSummaryConfirmed: Bool = false
    public var lensTypeRaw: String?
    public var stageRaw: String = Stage.capture.rawValue
    public var tags: [String] = []
    public var notes: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()
    public var archivedAt: Date?
    public var originRaw: String = IdeaOrigin.captured.rawValue
    public var pivotTypeRaw: String?
    /// File name of the voice recording this idea was captured from, if any.
    public var audioFileName: String?

    // Relationships. All optional or defaulted so CloudKit can be enabled later.
    public var pivotOf: Idea?
    @Relationship(inverse: \Idea.pivotOf) public var pivots: [Idea] = []
    @Relationship(deleteRule: .cascade) public var triage: OpportunityFilter?
    @Relationship(deleteRule: .cascade, inverse: \Exploration.idea) public var explorations: [Exploration] = []
    @Relationship(deleteRule: .cascade, inverse: \Evaluation.idea) public var evaluations: [Evaluation] = []
    @Relationship(deleteRule: .cascade, inverse: \Source.idea) public var sources: [Source] = []
    @Relationship(deleteRule: .cascade, inverse: \LibraryArtifact.idea) public var artifacts: [LibraryArtifact] = []
    @Relationship(deleteRule: .cascade, inverse: \Round.idea) public var rounds: [Round] = []
    @Relationship(deleteRule: .cascade, inverse: \Project.idea) public var project: Project?

    public init(originalText: String, title: String? = nil, origin: IdeaOrigin = .captured, audioFileName: String? = nil) {
        self.id = UUID()
        self.originalText = originalText
        self.title = title ?? Idea.suggestedTitle(from: originalText)
        self.originRaw = origin.rawValue
        self.audioFileName = audioFileName
        let now = Date()
        self.createdAt = now
        self.updatedAt = now
    }

    // MARK: Typed accessors

    public var stage: Stage {
        get { Stage(rawValue: stageRaw) ?? .capture }
        set { stageRaw = newValue.rawValue; touch() }
    }

    public var lensType: LensType? {
        get { lensTypeRaw.flatMap(LensType.init(rawValue:)) }
        set { lensTypeRaw = newValue?.rawValue; touch() }
    }

    public var origin: IdeaOrigin { IdeaOrigin(rawValue: originRaw) ?? .captured }

    public var pivotType: PivotType? {
        get { pivotTypeRaw.flatMap(PivotType.init(rawValue:)) }
        set { pivotTypeRaw = newValue?.rawValue }
    }

    public var isArchived: Bool { archivedAt != nil }

    public var latestEvaluation: Evaluation? {
        evaluations.max { $0.version < $1.version }
    }

    public func touch() { updatedAt = Date() }

    public func archive() {
        archivedAt = Date()
        stage = .archived
    }

    public func unarchive() {
        archivedAt = nil
        if stage == .archived { stage = .capture }
    }

    /// Starts a new, append-only evaluation version. Never mutates earlier versions.
    @discardableResult
    public func beginEvaluation(lens: LensType) -> Evaluation {
        let next = (evaluations.map(\.version).max() ?? 0) + 1
        let evaluation = Evaluation(lens: lens, version: next)
        evaluations.append(evaluation)
        touch()
        return evaluation
    }

    /// First line of the raw text, trimmed, at most 60 characters.
    public static func suggestedTitle(from text: String) -> String {
        let firstLine = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? "Untitled idea"
        if firstLine.count <= 60 { return firstLine }
        let cut = firstLine.prefix(60)
        if let lastSpace = cut.lastIndex(of: " ") {
            return String(cut[..<lastSpace]) + "…"
        }
        return String(cut) + "…"
    }
}
