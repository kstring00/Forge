import SwiftUI

/// One ring, 0–100, with a serif numeral. Potential and Confidence are always
/// two separate rings; only Confidence is ember. The breakdown arc arrives in Phase 4.
struct Ring: View {
    let value: Int
    let label: String
    var tint: Color = ForgeColor.ink
    var caption: String? = nil
    var size: CGFloat = 88

    private var fraction: Double { Double(min(max(value, 0), 100)) / 100 }

    var body: some View {
        VStack(spacing: ForgeSpacing.s) {
            Text(label).forgeLabel()
            ZStack {
                Circle()
                    .stroke(ForgeColor.line, lineWidth: 5)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)")
                    .font(ForgeType.numeral)
                    .foregroundStyle(ForgeColor.ink)
                    .monospacedDigit()
            }
            .frame(width: size, height: size)
            if let caption {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(ForgeColor.inkSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) out of 100")
    }
}

#Preview {
    HStack(spacing: 32) {
        Ring(value: 73, label: "Potential", caption: "Your structured assessment. Not a prediction.")
        Ring(value: 33, label: "Confidence", tint: ForgeColor.ember, caption: "Mostly enthusiasm so far.")
    }
    .padding()
    .background(ForgeColor.canvas)
}
