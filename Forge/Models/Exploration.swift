import Foundation
import SwiftData

/// One guided-thinking entry. `userText` is the user's; `aiText` is the AI's
/// and is shown as a suggestion until `confirmed` is true.
@Model
public final class Exploration {
    public var id: UUID = UUID()
    public var createdAt: Date = Date()
    public var promptKey: String = ""
    public var userText: String = ""
    public var aiText: String?
    public var confirmed: Bool = false
    public var idea: Idea?

    public init(promptKey: String, userText: String = "") {
        self.promptKey = promptKey
        self.userText = userText
    }
}
