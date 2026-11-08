import SwiftUI
import ForgeCore

/// Six orbs in a row (§8): 56 pt idle, 96 pt speaking with the others dimmed
/// to 40%, the verdict beneath in serif. A 1 pt hairline arcs between two
/// orbs whose verdicts conflict (on track against off track); tap the line for
/// the crossfire (§0A step 3). Agreement and "can't tell" draw nothing.
struct OrbRow: View {
    let verdicts: [Verdict]
    let crossfire: [Crossfire]
    var working: Set<Sphere> = []
    var lit: Set<Sphere> = []
    var isWorking = false
    @Binding var speaking: Sphere?
    var onCrossfire: ((SpherePair) -> Void)? = nil
    /// Rulings from the Brief, one tap each. Nil hides the buttons.
    var onRule: ((Verdict, RulingChoice) -> Void)? = nil

    private let order = Panel.order
    private let idleSize: CGFloat = 56
    private let speakingSize: CGFloat = 96

    private func verdict(for s: Sphere) -> Verdict? { verdicts.first { $0.sphere == s } }

    private func state(for s: Sphere) -> OrbState {
        if s == .steward { return .dormant }
        if isWorking { return lit.contains(s) ? .idle : .working }
        if let speaking { return speaking == s ? .speaking : .dim }
        if let v = verdict(for: s) { return .verdict(v.kind) }
        return .idle
    }

    private var splits: [SpherePair] { Panel.conflicts(verdicts.map { ($0.sphere, $0.kind) }) }

    var body: some View {
        VStack(spacing: ForgeSpacing.m) {
            GeometryReader { geo in
                let slot = geo.size.width / CGFloat(order.count)
                let centerY = geo.size.height / 2
                ZStack {
                    ForEach(splits) { pair in
                        hairline(pair, slot: slot, centerY: centerY)
                    }
                    ForEach(Array(order.enumerated()), id: \.element) { i, s in
                        let st = state(for: s)
                        Button {
                            guard s != .steward, !isWorking else { return }
                            withAnimation(ForgeMotion.settle) { speaking = speaking == s ? nil : s }
                        } label: {
                            OrbView(sphere: s, state: st, size: st == .speaking ? speakingSize : idleSize)
                        }
                        .buttonStyle(.plain)
                        .position(x: slot * (CGFloat(i) + 0.5), y: centerY)
                        .zIndex(st == .speaking ? 2 : 1)
                        .accessibilityLabel("\(s.displayName): \(verdict(for: s)?.kind.displayName ?? (s == .steward ? "arrives in Phase 5" : "no verdict"))")
                        .accessibilityAddTraits(speaking == s ? .isSelected : [])
                    }
                }
            }
            .frame(height: speakingSize + 16)

            if let speaking, let v = verdict(for: speaking) {
                speakingVerdict(speaking, v)
                    .transition(.opacity)
            } else if let speaking, speaking != .steward {
                Text("The \(speaking.displayName) has no verdict on this idea yet.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            } else if !splits.isEmpty && !isWorking {
                Text(splits.count == 1 ? "One line: two Spheres disagree. Tap it for the crossfire." : "\(splits.count) lines: the panel split. Tap one for the crossfire.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
    }

    /// An arc below the row, rising with the distance between the two orbs so
    /// several hairlines never lie on one another. Drawn as a shape with a wide
    /// invisible stroke so a finger can hit a 1 pt line.
    private func hairline(_ pair: SpherePair, slot: CGFloat, centerY: CGFloat) -> some View {
        let ia = CGFloat(order.firstIndex(of: pair.a) ?? 0)
        let ib = CGFloat(order.firstIndex(of: pair.b) ?? 0)
        let x1 = slot * (ia + 0.5), x2 = slot * (ib + 0.5)
        let dip = centerY + idleSize / 2 - 6 + CGFloat(pair.span) * 5
        var path = Path()
        path.move(to: CGPoint(x: x1, y: centerY))
        path.addQuadCurve(to: CGPoint(x: x2, y: centerY), control: CGPoint(x: (x1 + x2) / 2, y: dip))
        let involved = speaking.map { pair.contains($0) } ?? true
        return ZStack {
            // The hit area: a 24 pt band along the curve, so a finger finds a 1 pt line.
            path.stroke(Color.clear, lineWidth: 24)
                .contentShape(path.strokedPath(StrokeStyle(lineWidth: 24)))
                .onTapGesture { onCrossfire?(pair) }
            path.stroke(ForgeColor.line.opacity(involved ? 1 : 0.35), lineWidth: 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement()
        .accessibilityLabel("\(pair.a.displayName) and \(pair.b.displayName) disagree")
        .accessibilityHint("Opens the crossfire")
        .accessibilityAddTraits(.isButton)
    }

    private func speakingVerdict(_ sphere: Sphere, _ v: Verdict) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            HStack(spacing: ForgeSpacing.s) {
                Text(sphere.displayName).forgeLabel()
                Text(v.kind.displayName).forgeLabel().foregroundStyle(VerdictPalette.color(v.kind))
                Spacer()
                Text(v.criterionKey).forgeLabel()
            }
            Text(v.reason)
                .font(ForgeType.statement)
                .foregroundStyle(ForgeColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if v.kind == .cantTell, let need = v.evidenceNeeded {
                Text("Would change it: \(need)").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
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
            ForEach(splits.filter { $0.contains(sphere) }) { pair in
                Button { onCrossfire?(pair) } label: {
                    HStack(spacing: ForgeSpacing.xs) {
                        Rectangle().fill(ForgeColor.line).frame(width: 14, height: 1)
                        OrbView(sphere: pair.other(than: sphere), size: 12)
                        Text("Disagrees with the \(pair.other(than: sphere).displayName) · crossfire").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            if let onRule {
                HStack(spacing: ForgeSpacing.s) {
                    ForEach(RulingChoice.allCases, id: \.self) { choice in
                        let on = v.ruling?.choice == choice
                        Button { onRule(v, choice) } label: {
                            Text(choice.displayName)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(on ? .white : ForgeColor.ink)
                                .padding(.horizontal, 12).frame(height: 30)
                                .background(on ? ForgeColor.ember : ForgeColor.surface, in: Capsule())
                                .overlay(Capsule().strokeBorder(on ? Color.clear : ForgeColor.line))
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                    Spacer()
                }
                .padding(.top, ForgeSpacing.xs)
                if let r = v.ruling {
                    Text(r.choice == .findOut ? "Ruled: find out. An Experiment card is in the Journal entry." : "Ruled: \(r.choice.displayName.lowercased()). In the Journal.")
                        .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
        }
    }
}
