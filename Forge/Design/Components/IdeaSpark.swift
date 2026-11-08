import SwiftUI
import ForgeCore

/// "Idea sparks": every idea carries one living spark, drawn from gradients,
/// never an image. It starts as a seed of light, swirls with the panel's
/// colours while it is being formed, and catches fire once it is out in the
/// world. The panel's colours appear only after the panel has spoken.
///
/// - Seed (Idea): a lavender point of light in a dashed halo, slowly pulsing.
/// - Swirl (Formation): an angular gradient of the Sphere colours weighted by
///   verdict (on track full, can't tell faint, off track ember-tinted), an
///   inner shadow, a soft violet glow, and a bright diagonal seam when any pair
///   splits. It rotates slowly.
/// - Flame (Reality): an ember core with a glow and concentric rings, one per
///   logged conversation or payment, up to five, rippling outward.
///
/// 44 pt on cards, 128 pt on the idea page header. Still under Reduce Motion.
struct IdeaSpark: View {
    enum Stage: Equatable { case seed, swirl(weights: [(Sphere, Double, Bool)], split: Bool), flame(rings: Int)

        static func == (a: Stage, b: Stage) -> Bool {
            switch (a, b) {
            case (.seed, .seed): true
            case (.swirl(let wa, let sa), .swirl(let wb, let sb)): sa == sb && wa.map { "\($0.0)\($0.1)\($0.2)" } == wb.map { "\($0.0)\($0.1)\($0.2)" }
            case (.flame(let ra), .flame(let rb)): ra == rb
            default: false
            }
        }
    }

    let stage: Stage
    var size: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(stage: Stage, size: CGFloat = 44) {
        self.stage = stage
        self.size = size
    }

    /// The spark for an idea, from its track, its latest round and its project.
    init(idea: Idea, size: CGFloat = 44) {
        self.init(stage: IdeaSpark.stage(for: idea), size: size)
    }

    static func stage(for idea: Idea) -> Stage {
        switch idea.track {
        case .reality?:
            let talks = idea.project?.nextStepCount ?? 0
            let payments = idea.latestEvaluation?.allEvidence.filter { $0.ladderRung >= 4 && $0.countsTowardConfidence }.count ?? 0
            return .flame(rings: min(5, talks + payments))
        case .formation?:
            let verdicts = idea.rounds.max { $0.createdAt < $1.createdAt }?.verdicts ?? []
            guard !verdicts.isEmpty else { return .seed }
            let weights: [(Sphere, Double, Bool)] = Sphere.phase3Panel.map { s in
                guard let v = verdicts.first(where: { $0.sphere == s }) else { return (s, 0.35, false) }
                switch v.kind {
                case .onTrack: return (s, 1.0, false)
                case .cantTell: return (s, 0.35, false)
                case .offTrack: return (s, 0.8, true)
                }
            }
            let split = !Panel.conflicts(verdicts.map { ($0.sphere, $0.kind) }).isEmpty
            return .swirl(weights: weights, split: split)
        default:
            return .seed
        }
    }

    var body: some View {
        if reduceMotion || size < 24 {
            spark(at: 0).frame(width: size, height: size)
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { timeline in
                spark(at: timeline.date.timeIntervalSinceReferenceDate)
            }
            .frame(width: size, height: size)
        }
    }

    @ViewBuilder
    private func spark(at t: TimeInterval) -> some View {
        switch stage {
        case .seed: seed(t)
        case .swirl(let weights, let split): swirl(t, weights: weights, split: split)
        case .flame(let rings): flame(t, rings: rings)
        }
    }

    // MARK: Seed

    private func seed(_ t: TimeInterval) -> some View {
        let pulse = 0.5 + 0.5 * sin(t / 3 * 2 * .pi)   // a six-second breath
        let core = size * (0.34 + 0.05 * pulse)
        return ZStack {
            Circle()
                .strokeBorder(ForgeColor.lavender.opacity(0.55), style: StrokeStyle(lineWidth: max(1, size / 64), dash: [size / 14, size / 14]))
            Circle()
                .fill(RadialGradient(colors: [.white, Color(hex: 0xDCD6F5), ForgeColor.lavender.opacity(0.0)], center: .center, startRadius: 0, endRadius: core / 2))
                .frame(width: core, height: core)
                .shadow(color: ForgeColor.lavender.opacity(0.45 + 0.25 * pulse), radius: size * 0.12)
        }
        .accessibilityLabel("Idea, not yet checked")
    }

    // MARK: Swirl

    private func swirl(_ t: TimeInterval, weights: [(Sphere, Double, Bool)], split: Bool) -> some View {
        let angle = Angle.degrees((t / 24).truncatingRemainder(dividingBy: 1) * 360)   // one turn in 24 s
        var stops: [Gradient.Stop] = []
        let n = max(1, weights.count)
        for (i, w) in weights.enumerated() {
            let base = OrbView.palette(for: w.0).base
            let color = w.2 ? base.mixedToward(ForgeColor.ember, 0.55) : base
            let faded = ForgeColor.surface.mixedToward(color, w.1)
            stops.append(.init(color: faded, location: Double(i) / Double(n)))
        }
        if let first = stops.first { stops.append(.init(color: first.color, location: 1)) }
        return ZStack {
            Circle()
                .fill(AngularGradient(stops: stops, center: .center, angle: angle))
                .blur(radius: size * 0.04)
            // Inner shadow: dark at the rim.
            Circle()
                .fill(RadialGradient(colors: [.clear, .clear, .black.opacity(0.45)], center: UnitPoint(x: 0.4, y: 0.35), startRadius: 0, endRadius: size * 0.55))
            // Specular.
            Circle()
                .fill(RadialGradient(colors: [.white.opacity(0.5), .clear], center: UnitPoint(x: 0.32, y: 0.26), startRadius: 0, endRadius: size * 0.3))
            if split {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, .white.opacity(0.9), .clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: max(1, size / 40), height: size * 1.1)
                    .rotationEffect(.degrees(35))
                    .blur(radius: size * 0.01)
            }
        }
        .clipShape(Circle())
        .shadow(color: Color(hex: 0x8B63C9).opacity(0.45), radius: size * 0.14)
        .accessibilityLabel(split ? "In formation, the panel split" : "In formation")
    }

    // MARK: Flame

    private func flame(_ t: TimeInterval, rings: Int) -> some View {
        let phase = (t / 6).truncatingRemainder(dividingBy: 1)   // rings ripple out over six seconds
        return ZStack {
            ForEach(0..<max(0, min(rings, 5)), id: \.self) { i in
                let base = 0.55 + Double(i) * 0.11
                let r = base + 0.06 * phase
                Circle()
                    .strokeBorder(ForgeColor.ember.opacity(max(0, 0.55 - Double(i) * 0.09 - 0.2 * phase)), lineWidth: max(0.75, size / 60))
                    .frame(width: size * r, height: size * r)
            }
            Circle()
                .fill(RadialGradient(colors: [Color(hex: 0xFFF1D6), Color(hex: 0xF08A3E), ForgeColor.ember, Color(hex: 0x7A2E0E)], center: UnitPoint(x: 0.45, y: 0.42), startRadius: 0, endRadius: size * 0.27))
                .frame(width: size * 0.5, height: size * 0.5)
                .shadow(color: ForgeColor.ember.opacity(0.6), radius: size * 0.16)
        }
        .accessibilityLabel(rings == 0 ? "In reality" : "In reality, \(rings) \(rings == 1 ? "ring" : "rings") of traction")
    }
}

/// Three short segments, lavender · violet · ember, lit up to the idea's stage.
struct StageTrail: View {
    let track: Track?

    private let colors = [ForgeColor.lavender, Color(hex: 0x8B63C9), ForgeColor.ember]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3, id: \.self) { i in
                Capsule()
                    .fill(colors[i])
                    .frame(width: 14, height: 3)
                    .opacity(lit(i) ? 1 : 0.22)
            }
        }
        .accessibilityHidden(true)
    }

    private func lit(_ i: Int) -> Bool {
        guard let track else { return false }
        let index = Track.allCases.firstIndex(of: track) ?? 0
        return i <= index
    }
}

extension Color {
    /// A blend toward another colour, for weighting the swirl.
    func mixedToward(_ other: Color, _ amount: Double) -> Color {
        let a = UIColor(self), b = UIColor(other)
        var (r1, g1, b1, a1) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        var (r2, g2, b2, a2) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        a.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        b.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let t = CGFloat(min(max(amount, 0), 1))
        return Color(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, opacity: 1)
    }
}

#Preview("Idea sparks") {
    HStack(spacing: 32) {
        IdeaSpark(stage: .seed, size: 128)
        IdeaSpark(stage: .swirl(weights: [(.investor, 1, false), (.customer, 0.35, false), (.builder, 1, false), (.strategist, 0.8, true), (.skeptic, 0.35, false)], split: true), size: 128)
        IdeaSpark(stage: .flame(rings: 3), size: 128)
    }
    .padding(40)
    .background(ForgeColor.canvas)
}
