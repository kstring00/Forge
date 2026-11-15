import SwiftUI

/// A score out of 100 as a ring: the number in the middle and, when there is
/// room, "of 100" under it, so a 4 never reads as 4 out of 5. The one way the
/// app draws Potential and Confidence, at any size.
struct ScoreRing: View {
    let value: Int
    var size: CGFloat = 64
    var tint: Color = ForgeColor.ink

    private var fraction: Double { Double(min(max(value, 0), 100)) / 100 }
    private var lineWidth: CGFloat { max(3, size / 14) }

    var body: some View {
        ZStack {
            Circle().stroke(ForgeColor.line, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(fraction, 0.015))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(value)")
                    .font(Font.custom("Fraunces-Regular", size: size * 0.36))
                    .foregroundStyle(ForgeColor.ink)
                    .monospacedDigit()
                    .lineLimit(1).minimumScaleFactor(0.6)
                if size >= 56 {
                    Text("of 100")
                        .font(.system(size: max(9, size * 0.13), weight: .medium, design: .monospaced))
                        .foregroundStyle(ForgeColor.inkSecondary)
                        .lineLimit(1).minimumScaleFactor(0.8)
                }
            }
            .padding(lineWidth + 2)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(value) out of 100")
    }
}
