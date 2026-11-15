import SwiftUI
import ForgeCore

/// The idea's sky, full bleed, with the stage dots and the mono status line
/// from the canvas: "Evaluate · Business lens" and the date.
struct IdeaHeader: View {
    let idea: Idea

    private var statusLine: String {
        var parts = [idea.track?.displayName ?? "Archived"]
        if let lens = idea.lensType { parts.append("\(lens.displayName) idea") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            GrainGradient(colors: ForgeColor.sky(for: idea.stage))
            IdeaSpark(idea: idea, size: 128)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 64)
                .padding(.trailing, 20)
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(dotColor(i))
                            .frame(width: 8, height: 8)
                    }
                }
                .accessibilityHidden(true)
                HStack {
                    Text(statusLine)
                    Spacer()
                    Text(idea.createdAt.formatted(date: .abbreviated, time: .omitted))
                }
                .font(ForgeType.label)
                .textCase(.uppercase)
                .kerning(1.5)
                .foregroundStyle(Color(red: 0.165, green: 0.122, blue: 0.102))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(height: 240)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(statusLine). Captured \(idea.createdAt.formatted(date: .abbreviated, time: .omitted))")
    }

    private func dotColor(_ i: Int) -> Color {
        let colors = ForgeColor.sky(for: idea.stage)
        switch i {
        case 0: return colors.last ?? ForgeColor.ember
        case 1: return ForgeColor.RGB.mix(ForgeColor.RGB(0xE9, 0x99, 0x5C), ForgeColor.RGB(0xD9, 0x57, 0x2B), 0.3).color
        default: return colors.first ?? ForgeColor.lavender
        }
    }
}
