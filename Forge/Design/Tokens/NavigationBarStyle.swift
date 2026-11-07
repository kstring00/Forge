import UIKit

/// Screen titles (Home, Vault, Workshop, Settings and every pushed screen) in
/// Fraunces, matching the idea titles. SwiftUI has no font hook for the
/// navigation title, so this sets the UIKit appearance once at launch.
enum NavigationBarStyle {
    static func apply() {
        let large = scaled("Fraunces-SemiBold", size: 34, style: .largeTitle, fallbackWeight: .bold)
        let inline = scaled("Fraunces-SemiBold", size: 17, style: .headline, fallbackWeight: .semibold)
        let ink = UIColor(named: "Ink") ?? .label

        // Both the legacy properties and the appearance objects: SwiftUI builds
        // per-screen appearances (for example .toolbarBackground(.hidden)) from either.
        let bar = UINavigationBar.appearance()
        bar.largeTitleTextAttributes = [.font: large, .foregroundColor: ink]
        bar.titleTextAttributes = [.font: inline, .foregroundColor: ink]

        let standard = UINavigationBarAppearance()
        standard.configureWithDefaultBackground()
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        for a in [standard, edge] {
            a.largeTitleTextAttributes = [.font: large, .foregroundColor: ink]
            a.titleTextAttributes = [.font: inline, .foregroundColor: ink]
        }
        bar.standardAppearance = standard
        bar.compactAppearance = standard
        bar.scrollEdgeAppearance = edge
        bar.compactScrollEdgeAppearance = edge
    }

    private static func scaled(_ name: String, size: CGFloat, style: UIFont.TextStyle, fallbackWeight: UIFont.Weight) -> UIFont {
        let base = UIFont(name: name, size: size) ?? .systemFont(ofSize: size, weight: fallbackWeight)
        return UIFontMetrics(forTextStyle: style).scaledFont(for: base)
    }
}
