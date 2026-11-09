import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0038: what a card says about an idea, in words and shapes, never
/// a bare number. Two tiles side by side: how big it could be (the panel's
/// view, a word and five segments) and how far the proof has got (a four-step
/// ladder from the desk to a payment). Then the panel's best "What if…".
struct CardMeters: View {
    let idea: Idea

    private var evaluation: Evaluation? { idea.latestEvaluation }
    private var stage: ProofStage { ProofStage.of(idea) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            potentialTile
            proofTile
        }
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
        .accessibilityLabel(p.map { "Potential: \(PotentialWord.word($0)), \(ownedByPerson ? "your score" : "the panel's view")" } ?? "Potential not scored")
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
        .accessibilityLabel("Proof: \(stage.label)")
    }

    private func tile<V: View, C: View>(label: String, @ViewBuilder value: () -> V, @ViewBuilder caption: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).forgeLabelSmall()
            value()
            caption().font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(ForgeColor.canvas.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ForgeColor.line))
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
    /// Desk · Talked · Signups · Paid.
    var ladderIndex: Int {
        switch self {
        case .none: -1
        case .deskOnly: 0
        case .talked: 1
        case .signups: 2
        case .paid: 3
        }
    }

    var cardWord: String {
        switch self {
        case .none: "Not checked"
        case .deskOnly: "Desk only"
        case .talked(let n): "Talked to \(n)"
        case .signups(let n): "\(n) signups"
        case .paid: "Someone paid"
        }
    }

    var cardCaption: String {
        switch self {
        case .none: "nothing yet"
        case .deskOnly: "next: talk to people"
        case .talked(let n): n == 1 ? "one real conversation" : "\(n) real conversations"
        case .signups: "from your test page"
        case .paid: "the strongest proof"
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
