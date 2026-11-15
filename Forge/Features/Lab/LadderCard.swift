import SwiftUI
import ForgeCore

/// The evidence ladder as an actual vertical ladder with the current rung lit.
struct LadderCard: View {
    let evaluation: Evaluation

    private var criterion: Criterion? { evaluation.lens.criterion(evaluation.ladderKey) }
    private var current: Int { evaluation.criterionScore(for: evaluation.ladderKey)?.evidenceLevel ?? 0 }

    var body: some View {
        if let criterion {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("\(Plain.ladder) · \(criterion.title)").forgeSubhead().lineLimit(2)
                    Spacer()
                    Text("\(Plain.level(current)) of 5").forgeLabel().foregroundStyle(ForgeColor.emberText)
                }
                VStack(spacing: 0) {
                    ForEach(criterion.ladder.reversed()) { rung in
                        LadderRungRow(rung: rung, lit: rung.level == current, reached: rung.level <= current,
                                      isTop: rung.level == 5, isBottom: rung.level == 0)
                    }
                }
                Text(explanation(for: criterion))
                    .font(.system(.footnote))
                    .foregroundStyle(ForgeColor.ink.opacity(0.85))
                    .padding(.top, 8)
                    .overlay(alignment: .top) { Rectangle().fill(ForgeColor.line).frame(height: 1) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        }
    }

    private func explanation(for c: Criterion) -> String {
        let here = c.rung(current)?.worth ?? ""
        if current >= 5 { return here }
        let next = c.rung(current + 1)
        let step = Shortfalls.cheapestStep(reaching: current + 1, in: c)
        var text = here
        if let next { text += " Level \(next.level) needs: \(next.description.prefix(1).lowercased() + next.description.dropFirst())" }
        if let step { text += " Cheapest way there: \(step.title.lowercased())." }
        return text
    }
}

struct LadderRungRow: View {
    let rung: LadderRung
    let lit: Bool
    let reached: Bool
    let isTop: Bool
    let isBottom: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle().fill(isTop ? Color.clear : ForgeColor.line).frame(width: 2).frame(maxHeight: .infinity)
                ZStack {
                    Circle().fill(lit ? ForgeColor.ember : (reached ? ForgeColor.ink : ForgeColor.surface))
                    Circle().strokeBorder(lit ? ForgeColor.ember : (reached ? ForgeColor.ink : ForgeColor.line))
                    Text("\(rung.level)")
                        .font(ForgeType.numeralTiny)
                        .foregroundStyle(lit ? .white : (reached ? ForgeColor.canvas : ForgeColor.inkSecondary))
                }
                .frame(width: 24, height: 24)
                Rectangle().fill(isBottom ? Color.clear : ForgeColor.line).frame(width: 2).frame(maxHeight: .infinity)
            }
            .frame(width: 24)
            Text(rung.label)
                .font(.system(.footnote, weight: lit ? .semibold : .regular))
                .foregroundStyle(lit ? ForgeColor.ink : (reached ? ForgeColor.ink.opacity(0.85) : ForgeColor.inkSecondary))
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 40)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rung \(rung.level), \(rung.label)\(lit ? ", current" : reached ? ", reached" : "")")
    }
}
