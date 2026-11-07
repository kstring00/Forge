import SwiftUI
import ForgeCore

/// Six orbs in a row. Tap one: it grows, the others dim, its verdict appears
/// beneath in serif. A hairline connects two orbs whose verdicts disagree.
struct OrbRow: View {
    let verdicts: [Verdict]
    let crossfire: [Crossfire]
    var working: Set<Sphere> = []
    var lit: Set<Sphere> = []
    var isWorking = false
    @Binding var speaking: Sphere?
    var onCrossfire: ((Crossfire) -> Void)? = nil

    private let order: [Sphere] = [.customer, .investor, .strategist, .builder, .skeptic, .steward]

    private func verdict(for s: Sphere) -> Verdict? { verdicts.first { $0.sphere == s } }

    private func state(for s: Sphere) -> OrbState {
        if s == .steward { return .dim }
        if isWorking { return lit.contains(s) ? .idle : .working }
        if let speaking { return speaking == s ? .speaking : .dim }
        return .idle
    }

    private var disagreements: [(Sphere, Sphere, Crossfire)] {
        crossfire.map { ($0.fromSphere, $0.toSphere, $0) }
    }

    var body: some View {
        VStack(spacing: ForgeSpacing.m) {
            GeometryReader { geo in
                let slot = geo.size.width / CGFloat(order.count)
                let centerY = geo.size.height / 2
                ZStack {
                    // Disagreement hairlines, drawn under the orbs.
                    Canvas { ctx, _ in
                        for (a, b, _) in disagreements {
                            guard let ia = order.firstIndex(of: a), let ib = order.firstIndex(of: b) else { continue }
                            var p = Path()
                            p.move(to: CGPoint(x: slot * (CGFloat(ia) + 0.5), y: centerY))
                            p.addLine(to: CGPoint(x: slot * (CGFloat(ib) + 0.5), y: centerY))
                            ctx.stroke(p, with: .color(ForgeColor.line), lineWidth: 1)
                        }
                    }
                    .allowsHitTesting(false)
                    ForEach(Array(order.enumerated()), id: \.element) { i, s in
                        let st = state(for: s)
                        Button {
                            guard s != .steward, !isWorking else { return }
                            withAnimation(ForgeMotion.settle) { speaking = speaking == s ? nil : s }
                        } label: {
                            SphereOrb(sphere: s, size: st == .speaking ? 72 : 44, state: st)
                        }
                        .buttonStyle(.plain)
                        .position(x: slot * (CGFloat(i) + 0.5), y: centerY)
                        .accessibilityLabel("\(s.displayName): \(verdict(for: s)?.kind.displayName ?? (s == .steward ? "arrives in Phase 5" : "no verdict"))")
                        .accessibilityAddTraits(speaking == s ? .isSelected : [])
                    }
                }
            }
            .frame(height: 84)

            if let speaking, let v = verdict(for: speaking) {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    HStack(spacing: ForgeSpacing.s) {
                        Text(speaking.displayName).forgeLabel()
                        Text(v.kind.displayName).forgeLabel().foregroundStyle(verdictColor(v.kind))
                        Spacer()
                        Text(v.criterionKey).forgeLabel()
                    }
                    Text(v.reason)
                        .font(ForgeType.statement)
                        .foregroundStyle(ForgeColor.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    if v.kind == .cantTell, let need = v.evidenceNeeded {
                        Text("Needs: \(need)").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    }
                    if !v.sources.isEmpty {
                        HStack(spacing: ForgeSpacing.s) {
                            ForEach(v.sources.prefix(3)) { s in
                                HStack(spacing: 4) {
                                    EvidenceChip(pattern: EvidencePattern(s.sourceClass), size: 10)
                                    Text(s.title).font(.caption2).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
                                }
                            }
                        }
                    }
                    ForEach(crossfire.filter { $0.fromSphere == speaking || $0.toSphere == speaking }) { c in
                        Button { onCrossfire?(c) } label: {
                            HStack(spacing: ForgeSpacing.xs) {
                                SphereOrb(sphere: c.fromSphere, size: 12)
                                Text("→").font(.caption2).foregroundStyle(ForgeColor.inkSecondary)
                                SphereOrb(sphere: c.toSphere, size: 12)
                                Text(c.text).font(.caption).foregroundStyle(ForgeColor.ink).lineLimit(2)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(.opacity)
            } else if let speaking, speaking != .steward {
                Text("The \(speaking.displayName) has no verdict on this idea yet.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
    }

    private func verdictColor(_ k: VerdictKind) -> Color {
        switch k {
        case .onTrack: Color(hex: 0x7CCB9F)
        case .offTrack: Color(hex: 0xF2845C)
        case .cantTell: ForgeColor.inkSecondary
        }
    }
}
