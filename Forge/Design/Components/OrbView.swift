import SwiftUI
import ForgeCore

/// How an orb reads on screen. Brief §8 and the "The panel, up close" artboard.
enum OrbState: Equatable {
    /// No verdict yet: base, texture, soft glow.
    case idle
    /// A Reality Check is on it: brighter, texture moves faster.
    case working
    /// Holding a verdict: on track glows, can't tell fogs over, off track wears an ember ring.
    case verdict(VerdictKind)
    /// Tapped: 96 pt with a stronger halo. The caller dims the others.
    case speaking
    /// The others while one speaks: 40%.
    case dim
    /// The Steward before Phase 5: 22%.
    case dormant
}

/// A Sphere as an orb: its base radial gradient, a specular highlight and one
/// signature texture, layered gradients clipped to a circle, never an image.
/// Each texture moves on its own slow cycle (8 to 14 s, out of sync with the
/// others) and holds still under Reduce Motion. The one orb view the app uses.
///
/// Customer: ripples expanding. Investor: a warm sweep turning. Strategist: a
/// bright seam drifting. Builder: strata sliding. Skeptic: an eclipse bite
/// waxing and waning. Steward: a thin halo breathing.
struct OrbView: View {
    let sphere: Sphere
    var state: OrbState = .idle
    var size: CGFloat = 56

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var palette: Palette { OrbView.palette(for: sphere) }
    /// Chips under 24 pt do not animate; the texture still shows, frozen.
    private var animates: Bool { !reduceMotion && size >= 24 && state != .dormant && opacity > 0.3 }

    var body: some View {
        if animates {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                orb(at: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: size, height: size)
        } else {
            orb(at: 0).frame(width: size, height: size)
        }
    }

    // MARK: Drawing

    private func orb(at t: TimeInterval) -> some View {
        // Each Sphere has its own period and starts at its own point in the cycle.
        let cycle = state == .working ? palette.period / 3 : palette.period
        let phase = ((t / cycle) + palette.offset).truncatingRemainder(dividingBy: 1)
        return ZStack {
            base
            texture(phase: phase)
            highlight
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .saturation(saturation)
        .brightness(state == .working ? 0.06 : 0)
        .overlay(ring)
        .shadow(color: glow.color, radius: glow.radius, y: glow.radius * 0.1)
        .opacity(opacity)
        .accessibilityLabel(sphere.displayName)
        .accessibilityHidden(size < 24)
    }

    private var base: some View {
        Circle().fill(RadialGradient(
            stops: [.init(color: palette.light, location: 0), .init(color: palette.base, location: 0.47), .init(color: palette.deep, location: 1)],
            center: UnitPoint(x: 0.35, y: 0.30), startRadius: 0, endRadius: size * 0.96))
    }

    private var highlight: some View {
        Circle().fill(RadialGradient(
            stops: [.init(color: .white.opacity(0.55), location: 0), .init(color: .white.opacity(0.55), location: 0.05), .init(color: .clear, location: 0.22)],
            center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: size * 0.98))
    }

    @ViewBuilder
    private func texture(phase: Double) -> some View {
        switch sphere {
        case .customer: ripples(phase)
        case .investor: sweep(phase)
        case .strategist: seam(phase)
        case .builder: strata(phase)
        case .skeptic: eclipse(phase)
        case .steward: halo(phase)
        }
    }

    /// Concentric rings from a point below centre, expanding outward.
    private func ripples(_ phase: Double) -> some View {
        let spacing = 0.075, width = spacing * 0.22
        var stops: [Gradient.Stop] = [.init(color: .clear, location: 0)]
        var r = -spacing + phase * spacing
        while r < 1 {
            let a = max(r, 0), b = min(r + width, 1)
            if b > a {
                stops.append(.init(color: .clear, location: a))
                stops.append(.init(color: .white.opacity(0.16), location: a))
                stops.append(.init(color: .white.opacity(0.16), location: b))
                stops.append(.init(color: .clear, location: b))
            }
            r += spacing
        }
        stops.append(.init(color: .clear, location: 1))
        return Circle().fill(RadialGradient(stops: stops, center: UnitPoint(x: 0.5, y: 0.62), startRadius: 0, endRadius: size * 0.9))
    }

    /// A warm conic sweep, turning once per cycle.
    private func sweep(_ phase: Double) -> some View {
        Circle().fill(AngularGradient(
            stops: [.init(color: .clear, location: 0), .init(color: Color(red: 1, green: 0.925, blue: 0.745).opacity(0.6), location: 70 / 360),
                    .init(color: .clear, location: 140 / 360), .init(color: .clear, location: 1)],
            center: UnitPoint(x: 0.58, y: 0.62), angle: .degrees(120 + 360 * phase)))
    }

    /// One bright diagonal seam, drifting across and back.
    private func seam(_ phase: Double) -> some View {
        let d = 0.14 * sin(phase * 2 * .pi)
        let p = { (x: Double) in min(max(x + d, 0), 1) }
        return Circle().fill(LinearGradient(
            stops: [.init(color: .clear, location: 0), .init(color: .clear, location: p(0.50)), .init(color: .white.opacity(0.5), location: p(0.51)),
                    .init(color: .white.opacity(0.08), location: p(0.54)), .init(color: .clear, location: p(0.60)), .init(color: .clear, location: 1)],
            startPoint: UnitPoint(x: 0.06, y: 0.27), endPoint: UnitPoint(x: 0.94, y: 0.73)))
    }

    /// Fine near-horizontal strata, sliding.
    private func strata(_ phase: Double) -> some View {
        let spacing = 0.075, width = spacing * 0.22
        var stops: [Gradient.Stop] = [.init(color: .clear, location: 0)]
        var r = -spacing + phase * spacing
        while r < 1 {
            let a = max(r, 0), b = min(r + width, 1)
            if b > a {
                stops.append(.init(color: .clear, location: a))
                stops.append(.init(color: .white.opacity(0.12), location: a))
                stops.append(.init(color: .white.opacity(0.12), location: b))
                stops.append(.init(color: .clear, location: b))
            }
            r += spacing
        }
        stops.append(.init(color: .clear, location: 1))
        return Circle().fill(LinearGradient(stops: stops, startPoint: UnitPoint(x: 0.41, y: 0), endPoint: UnitPoint(x: 0.59, y: 1)))
    }

    /// A dark bite at the upper right, waxing and waning.
    private func eclipse(_ phase: Double) -> some View {
        let edge = 0.30 + 0.03 * sin(phase * 2 * .pi)
        let dark = Color(red: 24 / 255, green: 19 / 255, blue: 16 / 255)
        return Circle().fill(RadialGradient(
            stops: [.init(color: dark.opacity(0.88), location: 0), .init(color: dark.opacity(0.88), location: edge), .init(color: dark.opacity(0), location: edge + 0.04)],
            center: UnitPoint(x: 0.74, y: 0.30), startRadius: 0, endRadius: size * 1.02))
    }

    /// A thin inner ring, breathing.
    private func halo(_ phase: Double) -> some View {
        let r = 0.59 + 0.02 * sin(phase * 2 * .pi)
        let gold = Color(red: 1, green: 232 / 255, blue: 170 / 255).opacity(0.55 + 0.15 * sin(phase * 2 * .pi))
        return Circle().fill(RadialGradient(
            stops: [.init(color: .clear, location: 0), .init(color: .clear, location: r - 0.03), .init(color: gold, location: r), .init(color: .clear, location: r + 0.04)],
            center: .center, startRadius: 0, endRadius: size * 0.707))
    }

    // MARK: States

    /// Off track: a 1.5 pt ember ring with a 2 pt gap outside the orb.
    @ViewBuilder
    private var ring: some View {
        if case .verdict(.offTrack) = state {
            Circle()
                .strokeBorder(ForgeColor.emberText, lineWidth: 1.5)
                .frame(width: size + 7, height: size + 7)
        }
    }

    private var saturation: Double {
        switch state {
        case .verdict(.cantTell): 0.35
        case .working: 1.15
        default: 1
        }
    }

    private var opacity: Double {
        switch state {
        case .verdict(.cantTell): 0.55
        case .dim: 0.4
        case .dormant: 0.22
        default: 1
        }
    }

    private var glow: (color: Color, radius: CGFloat) {
        switch state {
        case .verdict(.cantTell), .dim, .dormant: (.clear, 0)
        case .speaking: (palette.base.opacity(0.5), size * 0.25)
        case .verdict(.offTrack): (ForgeColor.emberText.opacity(0.4), size * 0.14)
        case .working: (palette.base.opacity(0.45), size * 0.16)
        case .idle, .verdict: (palette.base.opacity(0.38), size * 0.14)
        }
    }

    // MARK: Palette

    struct Palette {
        let light: Color, base: Color, deep: Color
        /// Seconds per texture cycle, and where in the cycle this Sphere starts.
        let period: Double, offset: Double
    }

    /// The artboard's gradients: light, base, deep per Sphere.
    static func palette(for sphere: Sphere) -> Palette {
        switch sphere {
        case .customer: Palette(light: Color(hex: 0xDDF0FF), base: Color(hex: 0x4C8DC9), deep: Color(hex: 0x1E3F6E), period: 9, offset: 0.00)
        case .investor: Palette(light: Color(hex: 0xF6D9A0), base: Color(hex: 0xD9772B), deep: Color(hex: 0x7A2E0E), period: 12, offset: 0.37)
        case .strategist: Palette(light: Color(hex: 0xE4D5F6), base: Color(hex: 0x8B63C9), deep: Color(hex: 0x3B2466), period: 11, offset: 0.61)
        case .builder: Palette(light: Color(hex: 0xD8EBD3), base: Color(hex: 0x5F9E6E), deep: Color(hex: 0x22482C), period: 10, offset: 0.22)
        case .skeptic: Palette(light: Color(hex: 0xF2E6D8), base: Color(hex: 0x8F7B66), deep: Color(hex: 0x2E2520), period: 14, offset: 0.80)
        case .steward: Palette(light: Color(hex: 0xF2E3B0), base: Color(hex: 0xB8913A), deep: Color(hex: 0x4A3712), period: 8, offset: 0.49)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(red: Double((hex >> 16) & 0xFF) / 255, green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255)
    }
}

#Preview("The panel, up close") {
    VStack(spacing: 28) {
        HStack(spacing: 20) { ForEach(Sphere.allCases) { OrbView(sphere: $0, size: 96) } }
        HStack(spacing: 24) {
            OrbView(sphere: .investor, state: .verdict(.onTrack), size: 64)
            OrbView(sphere: .investor, state: .verdict(.cantTell), size: 64)
            OrbView(sphere: .investor, state: .verdict(.offTrack), size: 64)
            OrbView(sphere: .investor, state: .speaking, size: 96)
            OrbView(sphere: .steward, state: .dormant, size: 64)
        }
    }
    .padding(32)
    .background(ForgeColor.canvas)
}
