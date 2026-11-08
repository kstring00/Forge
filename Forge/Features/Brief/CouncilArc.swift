import SwiftUI
import ForgeCore

/// "Home A · the stage": the six orbs on a half-circle of 150 pt radius with
/// their names beneath, dashed ember lines between conflicting pairs, the
/// verdict inside the arc, and "Hear the panel →". Tap an orb to read that
/// voice under the arc; tap a line for the crossfire.
struct CouncilArc: View {
    let verdicts: [Verdict]
    let title: String
    let verdict: RealityVerdict?
    var working: Set<Sphere> = []
    var isWorking = false
    @Binding var speaking: Sphere?
    var onHear: (() -> Void)? = nil
    var onCrossfire: ((SpherePair) -> Void)? = nil
    var onRule: ((Verdict, RulingChoice) -> Void)? = nil

    private let radius: CGFloat = 150
    private let orbSize: CGFloat = 56
    private let order = Panel.order

    private func verdict(for s: Sphere) -> Verdict? { verdicts.first { $0.sphere == s } }
    private var splits: [SpherePair] { Panel.conflicts(verdicts.map { ($0.sphere, $0.kind) }) }

    /// Orb centres on the arc, left to right, in a box `2 * radius + orbSize` wide.
    private func center(_ i: Int, in size: CGSize) -> CGPoint {
        let angle = Double.pi - Double(i) / Double(order.count - 1) * Double.pi
        let cx = size.width / 2, cy = radius + orbSize / 2
        return CGPoint(x: cx + radius * cos(angle), y: cy - radius * sin(angle))
    }

    private func state(for s: Sphere) -> OrbState {
        if s == .steward { return .dormant }
        if isWorking { return working.contains(s) ? .working : .idle }
        if let speaking { return speaking == s ? .speaking : .dim }
        if let v = verdict(for: s) { return .verdict(v.kind) }
        return .idle
    }

    var body: some View {
        VStack(spacing: ForgeSpacing.m) {
            GeometryReader { geo in
                ZStack {
                    ForEach(splits) { pair in splitLine(pair, in: geo.size) }
                    ForEach(Array(order.enumerated()), id: \.element) { i, s in
                        let st = state(for: s)
                        let p = center(i, in: geo.size)
                        VStack(spacing: 6) {
                            Button {
                                guard s != .steward, !isWorking else { return }
                                withAnimation(ForgeMotion.settle) { speaking = speaking == s ? nil : s }
                            } label: {
                                OrbView(sphere: s, state: st, size: st == .speaking ? 72 : orbSize)
                            }
                            .buttonStyle(.plain)
                            Text(s.displayName)
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .textCase(.uppercase).kerning(1)
                                .foregroundStyle(speaking == s ? ForgeColor.emberText : ForgeColor.inkSecondary)
                                .opacity(s == .steward ? 0.5 : 1)
                        }
                        .position(x: p.x, y: p.y + 10)
                        .zIndex(st == .speaking ? 2 : 1)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(s.displayName): \(verdict(for: s)?.kind.displayName ?? (s == .steward ? "arrives in Phase 5" : "no verdict"))")
                        .accessibilityAddTraits(speaking == s ? .isSelected : [])
                    }
                    // Below the top orbs' name labels (which end near y = 115 at 390 pt), inside the arc's mouth.
                    inside.position(x: geo.size.width / 2, y: radius + orbSize / 2 + 34)
                }
            }
            .frame(height: radius + orbSize + 96)

            if let speaking, let v = verdict(for: speaking) {
                VerdictVoice(verdict: v, splits: splits.filter { $0.contains(speaking) }, onCrossfire: onCrossfire, onRule: onRule)
                    .transition(.opacity)
            } else if let speaking, speaking != .steward {
                Text("The \(speaking.displayName) has no verdict on this idea yet.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
    }

    /// The verdict, inside the arc.
    private var inside: some View {
        VStack(spacing: 4) {
            Text("The panel on").forgeLabelSmall()
            Text(title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink).lineLimit(1)
            if isWorking {
                Text("Working").font(ForgeType.statement).foregroundStyle(ForgeColor.inkSecondary)
            } else if let verdict {
                Text(verdict.displayName)
                    .font(ForgeType.numeral)
                    .foregroundStyle(ForgeColor.emberText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
                Text(verdict.explanation)
                    .font(.system(size: 12))
                    .foregroundStyle(ForgeColor.inkSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let onHear, !isWorking {
                Button(action: onHear) {
                    HStack(spacing: 4) {
                        Text("Hear the panel").forgeLabel().foregroundStyle(ForgeColor.ink)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                    }
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(width: 2 * radius - orbSize - 56)
    }

    /// A dashed ember line between two conflicting orbs; tapping it opens the crossfire.
    private func splitLine(_ pair: SpherePair, in size: CGSize) -> some View {
        let ia = order.firstIndex(of: pair.a) ?? 0, ib = order.firstIndex(of: pair.b) ?? 0
        let a = center(ia, in: size), b = center(ib, in: size)
        var path = Path()
        path.move(to: a)
        path.addLine(to: b)
        let involved = speaking.map { pair.contains($0) } ?? true
        return ZStack {
            path.stroke(Color.clear, lineWidth: 24)
                .contentShape(path.strokedPath(StrokeStyle(lineWidth: 24)))
                .onTapGesture { onCrossfire?(pair) }
            path.stroke(ForgeColor.emberText.opacity(involved ? 0.9 : 0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                .allowsHitTesting(false)
        }
        .accessibilityElement()
        .accessibilityLabel("\(pair.a.displayName) and \(pair.b.displayName) disagree")
        .accessibilityHint("Opens the crossfire")
        .accessibilityAddTraits(.isButton)
    }
}

/// One Sphere's verdict read under the arc, with its splits and the rulings.
struct VerdictVoice: View {
    let verdict: Verdict
    var splits: [SpherePair] = []
    var onCrossfire: ((SpherePair) -> Void)? = nil
    var onRule: ((Verdict, RulingChoice) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            HStack(spacing: ForgeSpacing.s) {
                Text(verdict.sphere.displayName).forgeLabel()
                Text(verdict.kind.displayName).forgeLabel().foregroundStyle(VerdictPalette.color(verdict.kind))
                Spacer()
                Text(verdict.criterionKey).forgeLabel()
            }
            Text(verdict.reason)
                .font(ForgeType.statement)
                .foregroundStyle(ForgeColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if verdict.kind == .cantTell, let need = verdict.evidenceNeeded {
                Text("Would change it: \(need)").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
            if !verdict.sources.isEmpty {
                HStack(spacing: ForgeSpacing.s) {
                    ForEach(verdict.sources.prefix(3)) { s in
                        HStack(spacing: 4) {
                            EvidenceChip(pattern: EvidencePattern(s.sourceClass), size: 10)
                            Text(s.title).font(.caption2).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
                        }
                    }
                }
            }
            ForEach(splits) { pair in
                Button { onCrossfire?(pair) } label: {
                    HStack(spacing: ForgeSpacing.xs) {
                        Rectangle().fill(ForgeColor.emberText).frame(width: 14, height: 1)
                        OrbView(sphere: pair.other(than: verdict.sphere), size: 12)
                        Text("Splits with the \(pair.other(than: verdict.sphere).displayName) · crossfire").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
            if let onRule {
                RulingButtons(current: verdict.ruling?.choice) { onRule(verdict, $0) }
                    .padding(.top, ForgeSpacing.xs)
                if let r = verdict.ruling {
                    Text(r.choice == .findOut ? "Ruled: find out. An Experiment card is in the Journal entry." : "Ruled: \(r.choice.displayName.lowercased()). In the Journal.")
                        .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
        }
    }
}

/// Agree · Disagree · Find out as pills, Find out outlined in ember (the canvas).
struct RulingButtons: View {
    var current: RulingChoice?
    var onRule: (RulingChoice) -> Void

    var body: some View {
        HStack(spacing: 8) {
            ForEach(RulingChoice.allCases, id: \.self) { choice in
                let on = current == choice
                let ember = choice == .findOut
                Button { onRule(choice) } label: {
                    Text(choice.displayName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(on ? .white : (ember ? ForgeColor.emberText : ForgeColor.ink))
                        .padding(.horizontal, 14).frame(height: 32)
                        .background(on ? ForgeColor.ember : ForgeColor.canvas, in: Capsule())
                        .overlay(Capsule().strokeBorder(on ? Color.clear : (ember ? ForgeColor.emberText : ForgeColor.line)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(choice.displayName)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
    }
}
