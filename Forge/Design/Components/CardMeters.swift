import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0038: what a card says about an idea, in words and shapes, never
/// a bare number. Two tiles side by side: how big it could be (the panel's
/// view, a word and five segments) and how far the proof has got (a four-step
/// ladder from the desk to a payment). Then the panel's best "What if…".
struct CardMeters: View {
    let idea: Idea
    @State private var explaining: MeterExplainerSheet.Focus?

    private var evaluation: Evaluation? { idea.latestEvaluation }
    private var stage: ProofStage { ProofStage.of(idea) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Button { explaining = .potential } label: { potentialTile }.buttonStyle(.plain)
            Button { explaining = .proof } label: { proofTile }.buttonStyle(.plain)
        }
        .sheet(item: $explaining) { MeterExplainerSheet(idea: idea, focus: $0) }
    }

    // MARK: Potential

    private var potentialTile: some View {
        let p = evaluation.flatMap { $0.criteria.isEmpty ? nil : $0.potential }
        return tile(label: "Potential") {
            if let p {
                Text(PotentialWord.word(p))
                    .font(Font.custom("Fraunces-SemiBold", size: 20, relativeTo: .title3))
                    .foregroundStyle(ForgeColor.ink)
                    .lineLimit(1).minimumScaleFactor(0.8)
                Segments(filled: PotentialWord.segments(p), of: 5)
            } else if let verdict = idea.latestRealityCheck?.verdict {
                Text(verdict.displayName)
                    .font(Font.custom("Fraunces-SemiBold", size: 18, relativeTo: .title3))
                    .foregroundStyle(ForgeColor.ink)
                    .lineLimit(2).minimumScaleFactor(0.8)
            }
        } caption: {
            Text(ownedByPerson ? "your score" : "the panel's view")
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(p.map { "Potential: \(PotentialWord.word($0)), \(ownedByPerson ? "your score" : "the panel's view"). Opens what it rests on." } ?? "Potential not scored")
    }

    /// "Your score" only when the person changed a score themselves, not when
    /// a logged conversation moved one.
    private var ownedByPerson: Bool {
        guard let e = evaluation else { return false }
        return e.criteria.contains { !$0.aiProposed && !$0.evidence.contains { $0.source?.sourceClass == .userVerified } }
    }

    // MARK: Proof

    private var proofTile: some View {
        tile(label: "Proof") {
            Text(stage.cardWord)
                .font(Font.custom("Fraunces-SemiBold", size: 20, relativeTo: .title3))
                .foregroundStyle(ForgeColor.ink)
                .lineLimit(1).minimumScaleFactor(0.8)
            ProofLadder(reached: stage.ladderIndex)
        } caption: {
            if let move = idea.proofMoves.last, move.isRecent() {
                Text("Up today · \(move.from)").foregroundStyle(ForgeColor.ink)
            } else {
                Text(stage.cardCaption)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Proof: \(stage.label), \(stage.cardCaption). Opens the four steps.")
    }

    private func tile<V: View, C: View>(label: String, @ViewBuilder value: () -> V, @ViewBuilder caption: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label).forgeLabelSmall()
                Spacer()
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary)
            }
            value()
            caption().font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(ForgeColor.canvas.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ForgeColor.line))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Potential 0–100 as a word and five segments. Never a bare number on a card.
enum PotentialWord {
    static func word(_ p: Int) -> String {
        switch p {
        case ..<20: "Long shot"
        case ..<40: "Modest"
        case ..<60: "Promising"
        case ..<80: "Strong"
        default: "Big"
        }
    }

    static func segments(_ p: Int) -> Int { min(5, max(1, p / 20 + 1)) }
}

extension ProofStage {
    /// The four steps of proof, the same words as "What did they give?":
    /// desk research · gave time (talked, or signed up) · paid · came back.
    static let steps: [(title: String, detail: String)] = [
        ("Looked up online", "The panel searched the web. That shows people buy things like this, not that anyone wants yours yet."),
        ("Gave time", "A real person talked with you about the problem, or signed up to hear more."),
        ("Paid", "Someone paid or put money down."),
        ("Came back", "Someone used it again, renewed, or asked for more. The strongest proof there is."),
    ]

    var ladderIndex: Int {
        switch self {
        case .none: -1
        case .deskOnly: 0
        case .talked, .signups: 1
        case .paid: 2
        case .cameBack: 3
        }
    }

    var cardWord: String {
        switch self {
        case .none: "Not checked"
        case .deskOnly: "Not tested yet"
        case .talked(let n): "Talked to \(n)"
        case .signups(let n): "\(n) signups"
        case .paid: "Someone paid"
        case .cameBack: "They came back"
        }
    }

    var cardCaption: String {
        switch self {
        case .none: "nothing yet"
        case .deskOnly: "step 1 of 4 · next: talk to people"
        case .talked: "step 2 of 4 · next: a payment"
        case .signups: "step 2 of 4 · next: a payment"
        case .paid: "step 3 of 4 · next: they come back"
        case .cameBack: "step 4 of 4 · the strongest proof"
        }
    }
}

struct Segments: View {
    let filled: Int
    let of: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<of, id: \.self) { i in
                Capsule().fill(i < filled ? ForgeColor.ink : ForgeColor.line).frame(height: 4)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Four dots on a line, lit up to where the proof has got.
struct ProofLadder: View {
    let reached: Int
    private let steps = 4

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<steps, id: \.self) { i in
                Circle()
                    .fill(i <= reached ? ForgeColor.ink : Color.clear)
                    .overlay(Circle().strokeBorder(i <= reached ? ForgeColor.ink : ForgeColor.line, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                if i < steps - 1 {
                    Rectangle().fill(i < reached ? ForgeColor.ink : ForgeColor.line).frame(height: 1.5)
                }
            }
        }
        .frame(height: 9)
        .accessibilityHidden(true)
    }
}

/// The panel's best "What if…" on the card, the one it hasn't been turned into
/// an idea yet. Opens the Brief, where the What-if cards are.
struct WhatIfTeaser: View {
    let idea: Idea

    private var pivot: PivotIdea? { idea.latestRealityCheck?.pivots.first { $0.spawnedIdeaID == nil } }

    var body: some View {
        if let pivot {
            NavigationLink(value: LabRoute.brief(ideaID: idea.id)) {
                HStack(alignment: .top, spacing: 10) {
                    SparkGlyph().padding(.top, 3)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(pivot.whatIf)
                            .font(Font.custom("Fraunces-Italic", size: 16, relativeTo: .body))
                            .foregroundStyle(ForgeColor.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Raises \(Lenses.criterion(pivot.fixes, in: idea.lensType ?? .business)?.title ?? pivot.fixes) · the panel's idea")
                            .forgeLabelSmall().lineLimit(1)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary).padding(.top, 3)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ForgeColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("The panel suggests: \(pivot.whatIf). Opens the Brief.")
        }
    }
}

/// Decision 0039: what a tile means, from a tap on it. Proof: the four steps,
/// where this idea is, what moves it next. Potential: the six criteria behind
/// the word, as the panel scored them.
struct MeterExplainerSheet: View {
    enum Focus: String, Identifiable { case potential, proof; var id: String { rawValue } }

    let idea: Idea
    let focus: Focus
    @Environment(\.dismiss) private var dismiss

    private var evaluation: Evaluation? { idea.latestEvaluation }
    private var stage: ProofStage { ProofStage.of(idea) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    if focus == .proof { proof } else { potential }
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xl)
            }
            .background(ForgeColor.canvas)
            .navigationTitle(focus == .proof ? "Proof" : "Potential")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .presentationDetents([.medium, .large])
    }

    private var proof: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            Text("How much the world has shown, not what anyone thinks. Four steps, each stronger than the last.")
                .font(.body).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            ForEach(Array(ProofStage.steps.enumerated()), id: \.offset) { i, step in
                let reached = i <= stage.ladderIndex
                let here = i == stage.ladderIndex
                HStack(alignment: .top, spacing: 12) {
                    VStack(spacing: 0) {
                        Circle().fill(reached ? ForgeColor.ink : Color.clear)
                            .overlay(Circle().strokeBorder(reached ? ForgeColor.ink : ForgeColor.line, lineWidth: 1.5))
                            .frame(width: 14, height: 14)
                        if i < ProofStage.steps.count - 1 {
                            Rectangle().fill(i < stage.ladderIndex ? ForgeColor.ink : ForgeColor.line).frame(width: 1.5).frame(minHeight: 36)
                        }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(step.title).forgeSubhead()
                            if here { Text("You are here").forgeLabelSmall() }
                        }
                        Text(step.detail).font(.subheadline).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
                        if here, case .talked(let n) = stage {
                            Text("\(n) \(n == 1 ? "conversation" : "conversations") logged.").font(.subheadline).foregroundStyle(ForgeColor.ink)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            if let e = evaluation, stage.showsNumber {
                Text("How sure the panel is now: \(e.confidence) of 100. The Brief shows what each part rests on.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var potential: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            if let e = evaluation, !e.criteria.isEmpty {
                Text("\(PotentialWord.word(e.potential)): how big this could be if it works, from the six things the panel scores. It's the panel's opinion until you change a score yourself.")
                    .font(.body).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                ForEach(e.lens.criteria) { c in
                    if let s = e.criterionScore(for: c.key) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(c.title).font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                                Spacer()
                                Text("\(s.score) of 5").font(.subheadline).foregroundStyle(ForgeColor.inkSecondary).monospacedDigit()
                            }
                            Segments(filled: s.score, of: 5)
                            if !s.note.isEmpty {
                                Text(s.note).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(3)
                            }
                        }
                    }
                }
                Text("Long shot is under 20 of 100, Modest under 40, Promising under 60, Strong under 80, Big above. Change any score in the idea's Lab.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Not scored yet. Get the panel's take, or score it yourself in the Lab.").font(.body).foregroundStyle(ForgeColor.ink)
            }
        }
    }
}
