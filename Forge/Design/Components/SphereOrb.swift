import SwiftUI
import ForgeCore

/// Brief v4 §8: a Sphere is a soft orb built from layered radial gradients with
/// a slight blur and an inner highlight, never a bitmap. States: idle (slow
/// drift of the gradient centre, still under Reduce Motion), working (brighter,
/// faster drift), speaking (larger; the caller dims the others), dim.
enum OrbState: Equatable {
    case idle, working, speaking, dim
}

struct SphereOrb: View {
    let sphere: Sphere
    var size: CGFloat = 56
    var state: OrbState = .idle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: (base: Color, light: Color, deep: Color) { SphereOrb.palette(for: sphere) }
    private var opacity: Double { state == .dim ? 0.4 : 1 }
    private var period: Double { state == .working ? 2.5 : 8 }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: reduceMotion && state != .working)) { timeline in
            let t = reduceMotion && state != .working ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let phase = (t.truncatingRemainder(dividingBy: period)) / period * 2 * .pi
            let cx = 0.38 + 0.08 * cos(phase)
            let cy = 0.34 + 0.06 * sin(phase * 1.3)
            ZStack {
                Circle().fill(palette.deep)
                Circle().fill(
                    RadialGradient(colors: [palette.base, palette.deep.opacity(0.0)],
                                   center: UnitPoint(x: 1 - cx, y: 1 - cy), startRadius: 0, endRadius: size * 0.75))
                Circle().fill(
                    RadialGradient(colors: [palette.light, palette.base.opacity(0.0)],
                                   center: UnitPoint(x: cx, y: cy), startRadius: 0, endRadius: size * 0.55))
                Circle().fill(
                    RadialGradient(colors: [Color.white.opacity(state == .working ? 0.55 : 0.35), .clear],
                                   center: UnitPoint(x: cx - 0.05, y: cy - 0.08), startRadius: 0, endRadius: size * 0.22))
            }
            .frame(width: size, height: size)
            .blur(radius: max(0.6, size * 0.012))
            .shadow(color: palette.deep.opacity(0.35), radius: size * 0.2, y: size * 0.12)
            .saturation(state == .working ? 1.15 : 1)
            .brightness(state == .working ? 0.06 : 0)
        }
        .frame(width: size, height: size)
        .opacity(opacity)
        .accessibilityLabel(sphere.displayName)
    }

    /// The canvas's gradients: light, base, deep per Sphere.
    static func palette(for sphere: Sphere) -> (base: Color, light: Color, deep: Color) {
        switch sphere {
        case .customer: (Color(hex: 0x4C8DC9), Color(hex: 0xBFE0F5), Color(hex: 0x1E3F6E))
        case .investor: (Color(hex: 0xD9772B), Color(hex: 0xF6D9A0), Color(hex: 0x7A2E0E))
        case .strategist: (Color(hex: 0x8B63C9), Color(hex: 0xE4D5F6), Color(hex: 0x3B2466))
        case .builder: (Color(hex: 0x5F9E6E), Color(hex: 0xD8EBD3), Color(hex: 0x22482C))
        case .skeptic: (Color(hex: 0x8F7B66), Color(hex: 0xF2E6D8), Color(hex: 0x2E2520))
        case .steward: (Color(hex: 0xC9A040), Color(hex: 0xF6E7B8), Color(hex: 0x5C4410))
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

#Preview {
    VStack(spacing: 24) {
        HStack(spacing: 16) { ForEach(Sphere.allCases) { SphereOrb(sphere: $0, size: 56) } }
        HStack(spacing: 16) {
            SphereOrb(sphere: .customer, size: 96, state: .speaking)
            SphereOrb(sphere: .investor, size: 56, state: .working)
            SphereOrb(sphere: .skeptic, size: 56, state: .dim)
        }
    }
    .padding()
    .background(ForgeColor.canvas)
}
