import Foundation
import SwiftData
import ForgeCore

/// §6C. The user's own charter, edited in Settings. One row. Ships as a
/// placeholder, never a default worldview. Used from Phase 5.
@Model
public final class StewardCharter {
    public var id: UUID = UUID()
    public var text: String = ""
    public var updatedAt: Date = Date()

    public init(text: String = "") {
        self.text = text
    }

    public var isPlaceholder: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public var displayText: String { isPlaceholder ? Spheres.charterPlaceholder : text }
}
