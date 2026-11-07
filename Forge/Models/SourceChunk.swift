import Foundation
import SwiftData

/// A passage of a Source, for citation anchoring. Grounded answers cite chunk IDs.
@Model
public final class SourceChunk {
    public var id: UUID = UUID()
    public var index: Int = 0
    public var text: String = ""
    public var source: Source?

    public init(index: Int, text: String) {
        self.index = index
        self.text = text
    }
}
