import SwiftUI

/// Marks AI-generated text. Muted, never ember.
struct SparkGlyph: View {
    var body: some View {
        Image(systemName: "sparkle")
            .font(.footnote)
            .foregroundStyle(ForgeColor.spark)
            .accessibilityLabel("AI generated")
    }
}

/// AI text: small sans in muted with the spark glyph in front.
struct AIText: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ForgeSpacing.xs) {
            SparkGlyph()
            Text(text)
                .font(ForgeType.aiText)
                .foregroundStyle(ForgeColor.spark)
        }
    }
}

/// The user's own words: italic serif with a 2pt ember rule on the left.
struct OriginalText: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: ForgeSpacing.m) {
            Rectangle()
                .fill(ForgeColor.ember)
                .frame(width: 2)
                .accessibilityHidden(true)
            Text(text)
                .font(ForgeType.originalText)
                .foregroundStyle(ForgeColor.ink)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}
