import SwiftUI

/// One ring, 0–100. Potential and Confidence are always two separate rings.
/// Phase 0 ships the shell; the Confidence breakdown arc arrives in Phase 4.
struct Ring: View {
    let value: Int
    let label: String
    var tint: Color = ForgeColor.ember
    var size: CGFloat = 88

    private var fraction: Double { Double(min(max(value, 0), 100)) / 100 }

    var body: some View {
        VStack(spacing: ForgeSpacing.s) {
            ZStack {
                Circle()
                    .stroke(ForgeColor.line, lineWidth: 6)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(tint, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(value)")
                    .font(.system(.title3, design: .default, weight: .medium))
                    .foregroundStyle(ForgeColor.ink)
                    .monospacedDigit()
            }
            .frame(width: size, height: size)
            Text(label).forgeLabel()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value) out of 100")
    }
}

#Preview {
    HStack(spacing: 32) {
        Ring(value: 72, label: "Potential")
        Ring(value: 28, label: "Confidence", tint: ForgeColor.sage)
    }
    .padding()
    .background(ForgeColor.canvas)
}
