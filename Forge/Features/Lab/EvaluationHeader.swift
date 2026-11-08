import SwiftUI
import ForgeCore

/// Two ring cards, never merged. Potential is ink; only Confidence is ember.
struct RingsRow: View {
    let evaluation: Evaluation

    var body: some View {
        HStack(alignment: .top, spacing: ForgeSpacing.m - 4) {
            RingCard(value: evaluation.potential, label: "Potential", tint: ForgeColor.ink,
                     caption: Plain.potential + ". " + "Your structured assessment. Not a prediction.", captionColor: ForgeColor.inkSecondary)
            RingCard(value: evaluation.confidence, label: "Confidence", tint: ForgeColor.ember,
                     caption: Plain.confidence + ". " + Scoring.isMostlyEnthusiasm(confidence: evaluation.confidence)
                        ? "Mostly enthusiasm so far."
                        : "Backed by what people did.",
                     captionColor: Scoring.isMostlyEnthusiasm(confidence: evaluation.confidence) ? ForgeColor.emberText : ForgeColor.inkSecondary)
        }
    }
}

struct RingCard: View {
    let value: Int
    let label: String
    let tint: Color
    let caption: String
    let captionColor: Color

    private var fraction: Double { Double(min(max(value, 0), 100)) / 100 }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s + 2) {
            Text(label).forgeLabel()
            ZStack {
                Circle().stroke(ForgeColor.line, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)")
                    .font(ForgeType.numeral)
                    .foregroundStyle(ForgeColor.ink)
                    .monospacedDigit()
            }
            .frame(width: 84, height: 84)
            Text(caption)
                .font(.system(.footnote))
                .foregroundStyle(captionColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) out of 100. \(caption)")
    }
}

/// Verified · AI-found · Assumption with the three pattern chips.
struct PatternLegend: View {
    let breakdown: ConfidenceBreakdown

    var body: some View {
        HStack(spacing: 14) {
            item(.solid, "Verified", breakdown.verifiedPercent)
            item(.stripes, "AI-found", breakdown.aiFoundPercent)
            item(.dots, "Assumption", breakdown.assumptionPercent)
            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    private func item(_ p: EvidencePattern, _ name: String, _ pct: Int) -> some View {
        HStack(spacing: 6) {
            EvidenceChip(pattern: p, size: 12)
            Text("\(name) \(pct)%")
                .font(ForgeType.label)
                .textCase(.uppercase)
                .kerning(0.9)
                .foregroundStyle(ForgeColor.inkSecondary)
        }
    }
}
