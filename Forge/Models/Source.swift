import Foundation
import SwiftData
import ForgeCore

/// One item in an idea's Research Library.
@Model
public final class Source {
    public var id: UUID = UUID()
    public var kindRaw: String = SourceKind.note.rawValue
    public var title: String = ""
    public var url: String?
    public var fileRef: String?
    public var fullText: String = ""
    public var aiSummary: String?
    public var sourceClassRaw: String = SourceClass.assumption.rawValue
    public var reviewed: Bool = false
    public var capturedAt: Date = Date()
    public var idea: Idea?
    @Relationship(deleteRule: .cascade, inverse: \SourceChunk.source) public var chunks: [SourceChunk] = []

    public init(kind: SourceKind, title: String, fullText: String, sourceClass: SourceClass, url: String? = nil) {
        self.kindRaw = kind.rawValue
        self.title = title
        self.fullText = fullText
        self.sourceClassRaw = sourceClass.rawValue
        self.url = url
    }

    public var kind: SourceKind { SourceKind(rawValue: kindRaw) ?? .note }

    public var sourceClass: SourceClass {
        get { SourceClass(rawValue: sourceClassRaw) ?? .assumption }
        set { sourceClassRaw = newValue.rawValue }
    }

    /// Decision 0037: the person's own evidence is lived; a fetched page is
    /// ranked by where it came from; the model's own notes are opinion.
    public var evidenceRank: EvidenceRank {
        switch sourceClass {
        case .userVerified: return .lived
        case .assumption: return .opinion
        case .aiFound: return url == nil ? .opinion : EvidenceRank.classify(url: url)
        }
    }
}
