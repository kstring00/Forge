import Foundation
import SwiftData
import ForgeCore

@Model
public final class LibraryArtifact {
    public var id: UUID = UUID()
    public var kindRaw: String = ArtifactKind.brief.rawValue
    public var content: String = ""
    public var audioRef: String?
    public var createdAt: Date = Date()
    public var idea: Idea?

    public init(kind: ArtifactKind, content: String, audioRef: String? = nil) {
        self.kindRaw = kind.rawValue
        self.content = content
        self.audioRef = audioRef
    }

    public var kind: ArtifactKind { ArtifactKind(rawValue: kindRaw) ?? .brief }
}
