import Foundation
import SwiftData

/// A standing constraint on future pitches, e.g. "no service businesses".
@Model
public final class Constraint {
    public var id: UUID = UUID()
    public var text: String = ""
    public var createdAt: Date = Date()
    public var fromPitch: Pitch?

    public init(text: String, fromPitch: Pitch? = nil) {
        self.text = text
        self.fromPitch = fromPitch
    }
}
