import SwiftUI

/// Brief v3.1 §8 and the design canvas. Fraunces (bundled, OFL, static
/// instances at optical size 36) for idea titles, the user's own words and every
/// number that matters; the system monospaced face stands in for IBM Plex Mono
/// on structure labels; the system sans for body. Sizes are the canvas's,
/// relative to text styles so Dynamic Type still scales them.
enum ForgeType {
    // Fraunces faces, by PostScript name.
    private static let serifRegular = "Fraunces-Regular"
    private static let serifSemiBold = "Fraunces-SemiBold"
    private static let serifItalic = "Fraunces-Italic"

    /// 34pt title on idea detail and project detail.
    static let ideaTitleHero = Font.custom(serifSemiBold, size: 34, relativeTo: .largeTitle)
    /// 22pt title on cards and sheets.
    static let ideaTitle = Font.custom(serifSemiBold, size: 22, relativeTo: .title2)
    /// The user's original words: 17pt italic, shown with a 2pt ember rule.
    static let originalText = Font.custom(serifItalic, size: 17, relativeTo: .body)
    /// Ring values: 28pt. Projection figures: 24pt. Criterion scores: 22pt. Ladder rung numbers: 12pt.
    static let numeral = Font.custom(serifRegular, size: 28, relativeTo: .title)
    static let numeralMedium = Font.custom(serifRegular, size: 24, relativeTo: .title2)
    static let numeralSmall = Font.custom(serifRegular, size: 22, relativeTo: .title3)
    static let numeralTiny = Font.custom(serifRegular, size: 12, relativeTo: .caption)
    /// 19pt serif for the riskiest assumption and other one-line statements.
    static let statement = Font.custom(serifRegular, size: 19, relativeTo: .title3)

    static let sectionTitle = Font.system(.headline, design: .default, weight: .semibold)
    static let body = Font.body
    static let secondary = Font.callout
    /// AI text: small sans, muted.
    static let aiText = Font.footnote
    /// Structure labels: 11pt mono, uppercase, wide tracking.
    static let label = Font.system(size: 11, weight: .medium, design: .monospaced)
    static let labelSmall = Font.system(size: 10, weight: .medium, design: .monospaced)
}

extension View {
    /// Structure label: monospaced, uppercase as small caps, 0.14em tracking, muted.
    func forgeLabel() -> some View {
        self
            .font(ForgeType.label)
            .textCase(.uppercase)
            .kerning(1.5)
            .foregroundStyle(ForgeColor.inkSecondary)
    }

    /// The smaller 10pt label used under projection figures and on ladder notes.
    func forgeLabelSmall() -> some View {
        self
            .font(ForgeType.labelSmall)
            .textCase(.uppercase)
            .kerning(0.6)
            .foregroundStyle(ForgeColor.inkSecondary)
    }
}
