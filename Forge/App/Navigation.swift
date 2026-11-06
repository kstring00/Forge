import Foundation

enum ForgeTab: String, Hashable, CaseIterable {
    case home, vault, workshop

    var title: String {
        switch self {
        case .home: "Home"
        case .vault: "Vault"
        case .workshop: "Workshop"
        }
    }

    var symbol: String {
        switch self {
        case .home: "circle.lefthalf.filled"
        case .vault: "archivebox"
        case .workshop: "hammer"
        }
    }
}

enum VaultRoute: Hashable {
    case idea(UUID)
}

enum WorkshopRoute: Hashable {
    case project(UUID)
}
