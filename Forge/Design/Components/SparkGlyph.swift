import SwiftUI

/// Marks AI-generated text. Always paired with `ForgeColor.spark`.
struct SparkGlyph: View {
    var body: some View {
        Image(systemName: "sparkle")
            .font(.caption2)
            .foregroundStyle(ForgeColor.spark)
            .accessibilityLabel("AI generated")
    }
}

/// AI text in its secondary colour with the spark glyph in front.
struct AIText: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: ForgeSpacing.xs) {
            SparkGlyph()
            Text(text)
                .font(ForgeType.secondary)
                .foregroundStyle(ForgeColor.spark)
        }
    }
}
