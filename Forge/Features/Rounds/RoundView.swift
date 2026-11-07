import SwiftUI
import SwiftData
import ForgeCore

/// §6C steps 2 to 5 on one screen, from `docs/design/source/round.template.html`:
/// the tally, one card per verdict led by its orb at 40 pt, Agree / Disagree /
/// Find out on each, crossfire where the panel split, and the summary once
/// every verdict is ruled. Rulings land in the Journal as they happen.
struct RoundView: View {
    @Bindable var round: Round
    @Environment(\.modelContext) private var context
    @State private var crossfirePair: SpherePair?
    @State private var noting: Verdict?

    private var idea: Idea? { round.idea }
    private var ordered: [Verdict] { Panel.order.compactMap { s in round.verdicts.first { $0.sphere == s } } }
    private var tally: RoundTally { RoundTally(round.verdicts.map { ($0.sphere, $0.kind, $0.ruling?.choice) }) }
    private var number: Int {
        guard let idea else { return 1 }
        let sorted = idea.rounds.sorted { $0.createdAt < $1.createdAt }
        return (sorted.firstIndex { $0.id == round.id } ?? 0) + 1
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Round \(number) · \(round.verdicts.count) \(round.verdicts.count == 1 ? "verdict" : "verdicts")").forgeLabel()
                Text("The panel on \(idea?.title ?? "this idea")")
                    .font(ForgeType.ideaTitleHero)
                    .foregroundStyle(ForgeColor.ink)
                Text("Each Sphere argues from its framework and only from your Library. No sources, no verdict. Your rulings land in the Journal; scores stay yours to change in the Lab.")
                    .font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)

                tallyRow

                VStack(spacing: 10) {
                    ForEach(ordered) { v in
                        VerdictCard(verdict: v, splits: tally.splits, onRule: { rule(v, $0) }, onCrossfire: { crossfirePair = $0 }, onNote: { noting = v })
                    }
                }

                if !tally.splits.isEmpty { crossfireButton }
                if tally.isComplete { summary }
                else {
                    Text("\(tally.unruled) of \(tally.total) still to rule on. The summary appears when every verdict has a ruling.")
                        .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, ForgeSpacing.m)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(ForgeColor.canvas)
        .navigationTitle("Round \(number)")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $crossfirePair) { pair in
            if let idea {
                CrossfireSheet(round: round, pair: pair, idea: idea)
            }
        }
        .sheet(item: $noting) { v in
            if let ruling = v.ruling {
                RulingNoteSheet(ruling: ruling, verdict: v)
            }
        }
    }

    // MARK: Pieces

    private var tallyRow: some View {
        HStack(spacing: 8) {
            tallyCell(tally.onTrack, "On track", VerdictPalette.onTrack)
            tallyCell(tally.offTrack, "Off track", VerdictPalette.offTrack)
            tallyCell(tally.cantTell, "Can't tell", ForgeColor.inkSecondary)
        }
    }

    private func tallyCell(_ n: Int, _ label: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(n)").font(ForgeType.numeralMedium).foregroundStyle(n == 0 ? ForgeColor.inkSecondary : tint)
            Text(label).forgeLabelSmall()
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .combine)
    }

    private var crossfireButton: some View {
        Button { crossfirePair = tally.splits.first } label: {
            HStack(spacing: 10) {
                ForEach(tally.splits.prefix(3)) { p in
                    HStack(spacing: -4) {
                        SphereOrb(sphere: p.a, size: 16)
                        SphereOrb(sphere: p.b, size: 16)
                    }
                }
                Text(tally.splits.count == 1 ? "Crossfire · one split" : "Crossfire · \(tally.splits.count) splits")
                Spacer()
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
            .modifier(SecondaryButtonChrome())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Crossfire, where the panel split")
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

/// One Sphere's verdict with the three rulings. Mirrors the canvas card.
struct VerdictCard: View {
    let verdict: Verdict
    var splits: [SpherePair] = []
    var onRule: (RulingChoice) -> Void
    var onCrossfire: ((SpherePair) -> Void)? = nil
    var onNote: (() -> Void)? = nil

    private var mySplits: [SpherePair] { splits.filter { $0.contains(verdict.sphere) } }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            SphereOrb(sphere: verdict.sphere, size: 40, state: verdict.ruling == nil ? .idle : .dim)
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verdict.sphere.displayName).font(.system(size: 14, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                    Spacer()
                    Text(verdict.kind.displayName).forgeLabel().foregroundStyle(VerdictPalette.color(verdict.kind))
                }
                Text(verdict.reason)
                    .font(.system(size: 13)).lineSpacing(2)
                    .foregroundStyle(Color(hex: 0xD9D2C7))
                    .fixedSize(horizontal: false, vertical: true)
                if verdict.kind == .cantTell, let need = verdict.evidenceNeeded {
                    Text("Would change it: \(need)").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
                HStack(spacing: 8) {
                    sourceLine
                    Spacer(minLength: 4)
                    rulingButtons
                }
                .padding(.top, 2)
                if let ruling = verdict.ruling { rulingLine(ruling) }
                ForEach(mySplits) { p in
                    Button { onCrossfire?(p) } label: {
                        HStack(spacing: 6) {
                            Rectangle().fill(ForgeColor.line).frame(width: 14, height: 1)
                            SphereOrb(sphere: p.other(than: verdict.sphere), size: 12)
                            Text("Splits with the \(p.other(than: verdict.sphere).displayName) · crossfire").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.top, 14).padding(.horizontal, 14).padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var sourceLine: some View {
        HStack(spacing: 4) {
            if let s = verdict.sources.first {
                EvidenceChip(pattern: EvidencePattern(s.sourceClass), size: 10)
                Text(verdict.sources.count > 1 ? "\(s.title) +\(verdict.sources.count - 1)" : s.title)
            } else {
                EvidenceChip(pattern: .dots, size: 10)
                Text("No source")
            }
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(ForgeColor.inkSecondary)
        .lineLimit(1)
    }

    private var rulingButtons: some View {
        HStack(spacing: 4) {
            roundButton("checkmark", "Agree", .agree)
            roundButton("xmark", "Disagree", .disagree)
            Button { onRule(.findOut) } label: {
                Text("Find out")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(verdict.ruling?.choice == .findOut ? .white : ForgeColor.canvas)
                    .padding(.horizontal, 10).frame(height: 30)
                    .background(verdict.ruling?.choice == .findOut ? ForgeColor.ember : ForgeColor.ink, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Find out")
            .accessibilityAddTraits(verdict.ruling?.choice == .findOut ? .isSelected : [])
        }
    }

    private func roundButton(_ symbol: String, _ label: String, _ choice: RulingChoice) -> some View {
        let on = verdict.ruling?.choice == choice
        return Button { onRule(choice) } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(on ? .white : ForgeColor.ink)
                .frame(width: 30, height: 30)
                .background(on ? ForgeColor.ember : ForgeColor.canvas, in: Circle())
                .overlay(Circle().strokeBorder(on ? Color.clear : ForgeColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func rulingLine(_ ruling: Ruling) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(ruling.choice.displayName).forgeLabelSmall().foregroundStyle(ForgeColor.emberText)
            Text(rulingSentence(ruling)).font(.caption).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            if ruling.choice != .findOut, let onNote {
                Button(ruling.note == nil ? "Say why" : "Edit") { onNote() }
                    .font(.caption.weight(.medium)).foregroundStyle(ForgeColor.ink)
            }
        }
        .padding(.top, 4)
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

/// §6C step 3, reached from the hairline between two orbs or a verdict card:
/// the two verdicts that conflict, the one exchange between them, and a ruling
/// on each. Never a chat.
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
                        SphereOrb(sphere: pair.a, size: 56)
                        Rectangle().fill(ForgeColor.line).frame(width: 48, height: 1)
                        SphereOrb(sphere: pair.b, size: 56)
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
                            Text("Neither Sphere replied to the other this round. The verdicts above are the whole disagreement.")
                                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                        }
                        ForEach(exchange) { c in
                            HStack(alignment: .top, spacing: ForgeSpacing.s) {
                                SphereOrb(sphere: c.fromSphere, size: 20)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("\(c.fromSphere.displayName) to the \(c.toSphere.displayName)").forgeLabelSmall()
                                    Text(c.text).font(ForgeType.statement).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        Text("One exchange per pair. This is not a chat; you rule.").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
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
