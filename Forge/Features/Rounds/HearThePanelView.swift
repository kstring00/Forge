import SwiftUI
import SwiftData
import ForgeCore

/// "Hear the panel" (brief v4.2 §6C): one card per Sphere, conflicting pairs
/// sat next to each other under an ember Split bracket that opens the
/// crossfire, Agree / Disagree / Find out on every card, the Steward as a
/// dashed placeholder until Phase 5, and the summary once every verdict is
/// ruled. Rulings land in the Journal as they happen. "Argue it out" arrives
/// with credits.
struct HearThePanelView: View {
    @Bindable var round: Round
    @Environment(\.modelContext) private var context
    @State private var crossfirePair: SpherePair?
    @State private var noting: Verdict?

    private var idea: Idea? { round.idea }
    private var tally: RoundTally { RoundTally(round.verdicts.map { ($0.sphere, $0.kind, $0.ruling?.choice) }) }
    private var number: Int {
        guard let idea else { return 1 }
        let sorted = idea.rounds.sorted { $0.createdAt < $1.createdAt }
        return (sorted.firstIndex { $0.id == round.id } ?? 0) + 1
    }

    /// The cards in panel order, except that each split pair sits together:
    /// the second of a pair moves up to follow the first.
    private var ordered: [Verdict] {
        var spheres = Panel.order.filter { s in round.verdicts.contains { $0.sphere == s } }
        for pair in tally.splits {
            guard let ia = spheres.firstIndex(of: pair.a), let ib = spheres.firstIndex(of: pair.b), ib != ia + 1 else { continue }
            spheres.remove(at: ib)
            let insertAt = spheres.firstIndex(of: pair.a)! + 1
            spheres.insert(pair.b, at: insertAt)
        }
        return spheres.compactMap { s in round.verdicts.first { $0.sphere == s } }
    }

    /// Which split pair, if any, a card index opens: the first card of an adjacent pair.
    private func bracket(at i: Int) -> SpherePair? {
        guard i + 1 < ordered.count else { return nil }
        return tally.splits.first { $0.contains(ordered[i].sphere) && $0.contains(ordered[i + 1].sphere) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                VStack(spacing: 10) {
                    ForEach(Array(ordered.enumerated()), id: \.element.id) { i, v in
                        let pair = bracket(at: i)
                        let above = i > 0 ? bracket(at: i - 1) : nil
                        VerdictCard(verdict: v, onRule: { rule(v, $0) }, onNote: { noting = v })
                            .overlay(alignment: .trailing) {
                                if let pair { SplitBracket(pair: pair) { crossfirePair = pair } }
                            }
                            .padding(.trailing, pair != nil || above != nil ? 14 : 0)
                    }
                    stewardPlaceholder
                }
                if tally.isComplete { summary }
                else {
                    Text("\(tally.unruled) of \(tally.total) still to rule on. The summary appears when every voice has a ruling.")
                        .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, ForgeSpacing.m)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(ForgeColor.canvas)
        .navigationTitle("Hear the panel")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $crossfirePair) { pair in
            if let idea { CrossfireSheet(round: round, pair: pair, idea: idea) }
        }
        .sheet(item: $noting) { v in
            if let ruling = v.ruling { RulingNoteSheet(ruling: ruling, verdict: v) }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Round \(number) · \(round.verdicts.count) \(round.verdicts.count == 1 ? "voice" : "voices")").forgeLabel()
            Text("Hear the panel on").forgeLabel().foregroundStyle(ForgeColor.emberText).padding(.top, 8)
            Text(idea?.title ?? "this idea")
                .font(ForgeType.ideaTitleHero)
                .foregroundStyle(ForgeColor.ink)
            if let v = idea?.latestRealityCheck?.verdict {
                Text(v.displayName).font(ForgeType.statement).foregroundStyle(ForgeColor.emberText)
            }
            Text("Each voice argues from its own framework and only from what was found. Rule on each one; your rulings go in the Journal. No score changes here.")
                .font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary).padding(.top, 4)
        }
    }

    /// The Steward arrives with the Personal Growth lens (Phase 5).
    private var stewardPlaceholder: some View {
        HStack(alignment: .top, spacing: 12) {
            OrbView(sphere: .steward, state: .dormant, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text("Steward").font(.system(size: 14, weight: .semibold)).foregroundStyle(ForgeColor.inkSecondary)
                Text("Whether this is worth your life right now. Arrives with the Personal Growth lens, arguing from a charter you write.")
                    .font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous)
            .strokeBorder(ForgeColor.line, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Summary").forgeLabel()
            Text(tally.panelLine).font(ForgeType.statement).foregroundStyle(ForgeColor.ink)
            ForEach(tally.splits) { p in
                Text("\(p.a.displayName) and \(p.b.displayName) split on \(splitKeys(p)).")
                    .font(.system(size: 13)).foregroundStyle(ForgeColor.ink.opacity(0.85))
            }
            Text(rulingsLine).font(.system(size: 13)).foregroundStyle(ForgeColor.ink.opacity(0.85))
            Text("No score changed. The Lab is where you change a score; here you only said what you believe.")
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            if let idea {
                NavigationLink(value: WorkshopRoute.journal) {
                    Text("\(idea.decisions.filter { $0.kind == .ruling }.count) rulings in the Journal").font(.caption.weight(.medium)).foregroundStyle(ForgeColor.ink)
                }
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6)))
    }

    private func splitKeys(_ p: SpherePair) -> String {
        let keys = round.verdicts.filter { p.contains($0.sphere) }.map(\.criterionKey)
        return Array(Set(keys)).sorted().joined(separator: " and ")
    }

    private var rulingsLine: String {
        var parts: [String] = []
        if tally.agreed > 0 { parts.append("agreed \(tally.agreed)") }
        if tally.disagreed > 0 { parts.append("disagreed \(tally.disagreed)") }
        if tally.findOut > 0 { parts.append("\(tally.findOut) to find out") }
        return "You " + parts.joined(separator: ", ") + "."
    }

    private func rule(_ v: Verdict, _ choice: RulingChoice) {
        guard let idea else { return }
        withAnimation(ForgeMotion.settle) {
            RulingActions.rule(v, choice, on: idea, in: context)
        }
        if choice == .disagree { noting = v }
    }
}

/// The ember bracket on the right of two adjacent cards that split. It hangs
/// from the first card's lower half to the second's upper half.
struct SplitBracket: View {
    let pair: SpherePair
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Text("Split")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .textCase(.uppercase).kerning(1)
                    .foregroundStyle(ForgeColor.emberText)
                    .rotationEffect(.degrees(90))
                    .fixedSize()
                    .frame(width: 12)
                BracketShape()
                    .stroke(ForgeColor.emberText, lineWidth: 1)
                    .frame(width: 8)
            }
            .frame(height: 120)
            .offset(x: 14, y: 70)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(pair.a.displayName) and \(pair.b.displayName) split. Open the crossfire.")
    }
}

/// A right-hand square bracket with rounded corners.
private struct BracketShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let r: CGFloat = 6
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + r), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX - r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

/// One voice: the orb in its verdict state, name, verdict, reason, the source
/// line, and the three rulings as pills.
struct VerdictCard: View {
    let verdict: Verdict
    var onRule: (RulingChoice) -> Void
    var onNote: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            OrbView(sphere: verdict.sphere, state: .verdict(verdict.kind), size: 40)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verdict.sphere.displayName).font(.system(size: 15, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                    Spacer()
                    Text(verdict.kind.displayName).forgeLabel().foregroundStyle(VerdictPalette.color(verdict.kind))
                }
                Text(verdict.reason)
                    .font(.system(size: 14)).lineSpacing(2)
                    .foregroundStyle(Color(hex: 0xD9D2C7))
                    .fixedSize(horizontal: false, vertical: true)
                sourceLine
                RulingButtons(current: verdict.ruling?.choice, onRule: onRule)
                    .padding(.top, 4)
                if let ruling = verdict.ruling { rulingLine(ruling) }
            }
        }
        .padding(.top, 14).padding(.horizontal, 14).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var sourceLine: some View {
        Group {
            if verdict.kind == .cantTell, let need = verdict.evidenceNeeded {
                Text("Needs: \(need)")
            } else if let s = verdict.sources.first {
                Text("Source: " + (verdict.sources.count > 1 ? "\(s.title) +\(verdict.sources.count - 1)" : s.title))
            } else {
                Text("No source")
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .textCase(.uppercase).kerning(0.6)
        .foregroundStyle(ForgeColor.inkSecondary)
        .lineLimit(1)
    }

    private func rulingLine(_ ruling: Ruling) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(rulingSentence(ruling)).font(.caption).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if ruling.choice != .findOut, let onNote {
                Button(ruling.note == nil ? "Say why" : "Edit") { onNote() }
                    .font(.caption.weight(.medium)).foregroundStyle(ForgeColor.ink)
            }
        }
    }

    private func rulingSentence(_ r: Ruling) -> String {
        switch r.choice {
        case .agree: r.resultingEvidence != nil ? "In the Journal. The cited source is attached to \(verdict.criterionKey) at the desk rung." : "In the Journal."
        case .disagree: r.note.map { "In the Journal as your belief: \($0)" } ?? "In the Journal as your belief against the panel's."
        case .findOut: "In the Journal. An Experiment card is drafted" + (r.resultingDecision?.expectedBy.map { ", due \($0.formatted(date: .abbreviated, time: .omitted))." } ?? ".")
        }
    }
}

/// Verdict colours from the canvas.
enum VerdictPalette {
    static let onTrack = Color(hex: 0x7CCB9F)
    static let offTrack = Color(hex: 0xF2845C)
    static func color(_ k: VerdictKind) -> Color {
        switch k {
        case .onTrack: onTrack
        case .offTrack: offTrack
        case .cantTell: ForgeColor.inkSecondary
        }
    }
}

/// §6C step 3, reached from the dashed line between two orbs or the Split
/// bracket: the two verdicts that conflict, the one exchange between them,
/// and a ruling on each. Never a chat.
struct CrossfireSheet: View {
    let round: Round
    let pair: SpherePair
    let idea: Idea
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private func verdict(_ s: Sphere) -> Verdict? { round.verdicts.first { $0.sphere == s } }
    private var exchange: [Crossfire] { round.crossfire.filter { pair.contains($0.fromSphere) && pair.contains($0.toSphere) } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    HStack(spacing: 0) {
                        Spacer()
                        OrbView(sphere: pair.a, state: verdict(pair.a).map { .verdict($0.kind) } ?? .idle, size: 56)
                        Rectangle().fill(ForgeColor.emberText).frame(width: 48, height: 1)
                        OrbView(sphere: pair.b, state: verdict(pair.b).map { .verdict($0.kind) } ?? .idle, size: 56)
                        Spacer()
                    }
                    .padding(.top, ForgeSpacing.m)
                    Text("\(pair.a.displayName) and \(pair.b.displayName) disagree")
                        .font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)

                    ForEach([pair.a, pair.b], id: \.self) { s in
                        if let v = verdict(s) {
                            VerdictCard(verdict: v, onRule: { choice in
                                withAnimation(ForgeMotion.settle) { RulingActions.rule(v, choice, on: idea, in: context) }
                            })
                        }
                    }

                    VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                        Text("Crossfire").forgeLabel()
                        if exchange.isEmpty {
                            Text("Neither voice replied to the other this round. The verdicts above are the whole disagreement.")
                                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                        }
                        ForEach(exchange) { c in
                            HStack(alignment: .top, spacing: ForgeSpacing.s) {
                                OrbView(sphere: c.fromSphere, size: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(c.fromSphere.displayName) to the \(c.toSphere.displayName)").forgeLabelSmall()
                                    Text(c.text).font(ForgeType.statement).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        Text("One exchange per pair. This is not a chat; you rule. Side with one for free.").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, ForgeSpacing.xxl)
            }
            .background(ForgeColor.canvas)
            .navigationTitle("Crossfire")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.large])
    }
}

/// The user's own words on a ruling. On Disagree they become the belief on record.
struct RulingNoteSheet: View {
    @Bindable var ruling: Ruling
    let verdict: Verdict
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(ruling.choice == .disagree ? "What you believe instead" : "Why", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                } header: {
                    Text(ruling.choice == .disagree ? "Your belief" : "Your note")
                } footer: {
                    Text(ruling.choice == .disagree
                         ? "Saved as an assumption in the Library and as the belief on this Journal entry. It raises nothing; it is on record to be checked against what happens."
                         : "Kept on the Journal entry.")
                }
                Section("The \(verdict.sphere.displayName) said") {
                    Text(verdict.reason).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ForgeColor.canvas)
            .navigationTitle(ruling.choice.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Skip") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { RulingActions.setNote(text, on: ruling); dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear { text = ruling.note ?? "" }
        }
        .presentationDetents([.medium])
    }
}
