import SwiftUI
import ForgeCore

/// Evidence as pattern, not colour: verified = solid, AI-found = diagonal
/// stripes, assumption = dot grid. Readable without reading, and in both themes.
enum EvidencePattern {
    case solid, stripes, dots

    init(_ sourceClass: SourceClass) {
        switch sourceClass {
        case .userVerified: self = .solid
        case .aiFound: self = .stripes
        case .assumption: self = .dots
        }
    }
}

struct EvidenceFill: View {
    var pattern: EvidencePattern
    var color: Color = ForgeColor.ink
    var pitch: CGFloat = 6

    var body: some View {
        switch pattern {
        case .solid:
            Rectangle().fill(color)
        case .stripes:
            Canvas { context, size in
                let span = size.width + size.height
                var x: CGFloat = -size.height
                while x < span {
                    var p = Path()
                    p.move(to: CGPoint(x: x, y: size.height))
                    p.addLine(to: CGPoint(x: x + size.height, y: 0))
                    context.stroke(p, with: .color(color), lineWidth: 1.5)
                    x += pitch
                }
            }
        case .dots:
            Canvas { context, size in
                var y: CGFloat = pitch / 2
                while y < size.height {
                    var x: CGFloat = pitch / 2
                    while x < size.width {
                        context.fill(Path(ellipseIn: CGRect(x: x - 1, y: y - 1, width: 2, height: 2)), with: .color(color))
                        x += pitch
                    }
                    y += pitch
                }
            }
        }
    }
}

/// A small square chip carrying one evidence pattern, as on criterion rows.
struct EvidenceChip: View {
    var pattern: EvidencePattern
    var size: CGFloat = 14

    var body: some View {
        EvidenceFill(pattern: pattern)
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).strokeBorder(ForgeColor.line))
            .accessibilityLabel(label)
    }

    private var label: String {
        switch pattern {
        case .solid: "Verified"
        case .stripes: "Found by AI"
        case .dots: "Assumption"
        }
    }
}

#Preview {
    HStack(spacing: 12) {
        EvidenceChip(pattern: .solid)
        EvidenceChip(pattern: .stripes)
        EvidenceChip(pattern: .dots)
    }
    .padding()
    .background(ForgeColor.canvas)
}
