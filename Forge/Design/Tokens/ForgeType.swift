import SwiftUI

/// One display face for idea titles (system serif, "New York"), system text
/// for everything else, monospaced only for small metadata labels.
/// All styles are relative to Dynamic Type.
enum ForgeType {
    static let ideaTitleHero = Font.system(.largeTitle, design: .serif, weight: .semibold)
    static let ideaTitle = Font.system(.title2, design: .serif, weight: .semibold)
    static let sectionTitle = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.body
    static let secondary = Font.callout
    static let label = Font.system(.caption, design: .monospaced, weight: .medium)
    static let numeral = Font.system(.largeTitle, design: .default, weight: .light)
}

extension View {
    /// Small uppercase monospaced label, as in the reference screens.
    func forgeLabel() -> some View {
        self
            .font(ForgeType.label)
            .textCase(.uppercase)
            .kerning(1.1)
            .foregroundStyle(ForgeColor.inkSecondary)
    }
}
