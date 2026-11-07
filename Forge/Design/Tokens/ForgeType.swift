import SwiftUI

/// Brief v3.1 §8. Serif for idea titles, the user's own words and every number
/// that matters; monospaced small caps with wide tracking for structure labels;
/// system sans for body. The brief names Fraunces, IBM Plex Mono and Inter; the
/// system equivalents (New York, SF Mono, SF) are used so no font files ship.
/// Each token is one line to swap. All styles scale with Dynamic Type.
enum ForgeType {
    static let ideaTitleHero = Font.system(.largeTitle, design: .serif, weight: .semibold)
    static let ideaTitle = Font.system(.title2, design: .serif, weight: .semibold)
    /// The user's original words: italic serif, shown with a 2pt ember rule.
    static let originalText = Font.system(.body, design: .serif).italic()
    /// Numbers that matter: ring values, projection figures, scores.
    static let numeral = Font.system(.title, design: .serif, weight: .regular)
    static let numeralLarge = Font.system(.largeTitle, design: .serif, weight: .regular)
    static let sectionTitle = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.body
    static let secondary = Font.callout
    /// AI text: small sans, muted.
    static let aiText = Font.footnote
    static let label = Font.system(.caption2, design: .monospaced, weight: .medium)
}

extension View {
    /// Structure label: monospaced, uppercase as small caps, wide tracking, muted.
    func forgeLabel() -> some View {
        self
            .font(ForgeType.label)
            .textCase(.uppercase)
            .kerning(1.6)
            .foregroundStyle(ForgeColor.inkSecondary)
    }
}
