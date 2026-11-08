import SwiftUI

/// Dark is the default theme (brief v3.1 §8); light is a secondary inversion.
enum Appearance: String, CaseIterable, Identifiable {
    case dark, light, system

    static let storageKey = "appearance"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dark: "Dark"
        case .light: "Light"
        case .system: "Match system"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }

    var interfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: .unspecified
        }
    }

    /// Dark is the default (§8). `preferredColorScheme` covers SwiftUI; this
    /// covers every window, so presented sheets and UIKit chrome match.
    @MainActor
    static func applyToWindows(_ appearance: Appearance) {
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows { window.overrideUserInterfaceStyle = appearance.interfaceStyle }
        }
    }
}
