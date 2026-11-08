import Foundation
import ForgeCore

/// Brief v4.2 §2: Home, then one tab per track.
enum ForgeTab: String, Hashable, CaseIterable {
    case home, idea, formation, reality

    var title: String {
        switch self {
        case .home: "Home"
        case .idea: Track.idea.displayName
        case .formation: Track.formation.displayName
        case .reality: Track.reality.displayName
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .idea: "lightbulb"
        case .formation: "circle.hexagonpath"
        case .reality: "hammer"
        }
    }

    init(_ track: Track) {
        switch track {
        case .idea: self = .idea
        case .formation: self = .formation
        case .reality: self = .reality
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
}
