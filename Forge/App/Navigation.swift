import Foundation
import ForgeCore

/// Decision 0025: Home · Ideas · Journal; decision 0040 adds Sparks, every
/// "What if…" the panel has offered, across all ideas.
enum ForgeTab: String, Hashable, CaseIterable {
    case home, ideas, sparks, journal

    var title: String {
        switch self {
        case .home: "Home"
        case .ideas: "Ideas"
        case .sparks: "Sparks"
        case .journal: "Journal"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .ideas: "lightbulb"
        case .sparks: "sparkles"
        case .journal: "book.closed"
        }
    }
}

enum VaultRoute: Hashable {
    case idea(UUID)
}

enum WorkshopRoute: Hashable {
    case project(UUID)
    case journal
}

enum LabRoute: Hashable {
    case criterion(evaluationID: UUID, key: String)
    case history(ideaID: UUID)
    case round(roundID: UUID)
    /// The criteria with their evidence, from the "What's riding on it" rings.
    case criteria(ideaID: UUID)
    /// The full Brief, from "The panel's take" (decision 0023).
    case brief(ideaID: UUID)
}

/// An idea id a sheet can be driven by.
struct IdeaRef: Identifiable, Hashable {
    let id: UUID
}

/// How capture was asked for: typing, or straight into voice.
enum CaptureRequest: String, Identifiable {
    case text, voice
    var id: String { rawValue }
}
