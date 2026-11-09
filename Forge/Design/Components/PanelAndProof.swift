import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0037: proof as a stage, from what the person brought back from the
/// world. Desk research alone is a stage, not a number.
enum ProofStage: Equatable {
    case none
    case deskOnly
    case talked(Int)
    case signups(Int)
    case paid
    /// Someone used it again or asked for more (proof level 5).
    case cameBack

    static func of(_ idea: Idea) -> ProofStage {
        let lived = idea.latestEvaluation?.allEvidence.filter { $0.source?.sourceClass == .userVerified } ?? []
        if lived.contains(where: { $0.ladderRung >= 5 }) { return .cameBack }
        if lived.contains(where: { $0.ladderRung >= 4 }) || (idea.latestEvaluation?.projection.verifiedUnits ?? 0) > 0 { return .paid }
        let talked = idea.sources.filter { $0.sourceClass == .userVerified && $0.title.hasPrefix(FieldEvidence.conversationKind) }.count
        if talked > 0 { return .talked(talked) }
        // Signups arrive with test pages (engine step 6).
        return idea.latestRealityCheck != nil || idea.latestEvaluation != nil ? .deskOnly : .none
    }

    var label: String {
        switch self {
        case .none: ""
        case .deskOnly: "Desk research only"
        case .talked(let n): "Talked to people · \(n)"
        case .signups(let n): "Signups · \(n)"
        case .paid: "Someone paid"
        case .cameBack: "Someone came back"
        }
    }

    /// The proof number appears only once a person has brought something back.
    var showsNumber: Bool {
        switch self {
        case .talked, .signups, .paid, .cameBack: true
        case .none, .deskOnly: false
        }
    }
}

/// On cards: the panel's view of potential (marked as its opinion), then proof
/// as a stage, and "+7 from Dale" for a day after it moves. No "Confidence".
struct PanelAndProof: View {
    let idea: Idea

    private var evaluation: Evaluation? { idea.latestEvaluation }
    private var stage: ProofStage { ProofStage.of(idea) }
    private var recent: ProofMove? { idea.proofMoves.last.flatMap { $0.isRecent() ? $0 : nil } }
    private var panels: Bool { evaluation?.criteria.allSatisfy(\.aiProposed) ?? true }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if let e = evaluation, !e.criteria.isEmpty {
                    Text("Potential \(e.potential)").font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                    Text(panels ? "· the panel's view" : "· your score").forgeLabelSmall()
                } else if let verdict = idea.latestRealityCheck?.verdict {
                    Text(verdict.displayName).forgeLabel()
                    Text("· the panel's view").forgeLabelSmall()
                }
            }
            if stage != .none {
                HStack(spacing: 6) {
                    Image(systemName: stage == .deskOnly ? "doc.text.magnifyingglass" : "person.2.fill")
                        .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    Text(stage.label + (stage.showsNumber ? " · proof \(evaluation?.confidence ?? 0)" : ""))
                        .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(1)
                    if let recent {
                        Text(recent.line).font(.system(.footnote, weight: .semibold)).foregroundStyle(ForgeColor.ink).lineLimit(1)
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// On the Brief: the finer number's breakdown, criterion by criterion, and
/// every move in proof, for good.
struct ProofBreakdownView: View {
    let idea: Idea
    let evaluation: Evaluation

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("What the \(evaluation.confidence) rests on").forgeSubhead()
            ForEach(evaluation.lens.criteria) { c in
                if let s = evaluation.criterionScore(for: c.key) { line(c.title, s) }
            }
            Text("Desk research adds up to 1 level per criterion, more for independent reviewed or published sources than for one forum post. What you bring back from people counts from level 3.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            if !idea.proofMoves.isEmpty {
                Text("Proof history").forgeLabel().padding(.top, ForgeSpacing.s)
                ForEach(idea.proofMoves.reversed()) { m in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(m.at.formatted(.dateTime.month(.abbreviated).day())).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                        Text(m.line).font(.system(.footnote, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                        if let t = m.criterionTitle { Text("· \(t) to level \(m.levelAfter)").font(.footnote).foregroundStyle(ForgeColor.inkSecondary) }
                    }
                }
            }
        }
    }

    private func line(_ title: String, _ s: CriterionScore) -> some View {
        let text: String
        if s.evidenceLevel >= 3 {
            text = "\(title) · level \(s.evidenceLevel) · from people"
        } else if s.aiProposed, let d = s.deskLevel, s.deskSourceCount > 0 {
            text = "+\(String(format: "%.1f", d - DeskGrade.floor)) \(title): \(s.deskSourceCount) \(s.deskSourceCount == 1 ? "source" : "sources")"
        } else {
            text = "\(title) · level \(String(format: "%.1f", s.effectiveLevel)) · no source"
        }
        return HStack(spacing: 6) {
            EvidenceChip(pattern: s.evidenceLevel >= 3 ? .solid : (s.deskSourceCount > 0 ? .stripes : .dots), size: 10)
            Text(text).font(.subheadline).foregroundStyle(ForgeColor.ink).lineLimit(1)
        }
    }
}
