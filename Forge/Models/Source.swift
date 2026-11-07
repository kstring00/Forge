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
}
