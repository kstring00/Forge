import SwiftUI
import ForgeCore

/// Criterion rows as on the canvas: name and note, pattern chip, a 5×32
/// vertical gauge, and the serif score. Each opens the criterion screen.
struct CriteriaList: View {
    let evaluation: Evaluation

    private var frameworks: String {
        var seen: [String] = []
        for f in evaluation.lens.frameworks.map(\.name) where !seen.contains(f) { seen.append(f) }
        return seen.prefix(3).joined(separator: ", ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Criteria").forgeLabel()
            if !frameworks.isEmpty {
                Text("Drawn from \(frameworks)")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
            Spacer().frame(height: ForgeSpacing.s)
            ForEach(evaluation.lens.criteria) { criterion in
                NavigationLink(value: LabRoute.criterion(evaluationID: evaluation.id, key: criterion.key)) {
                    CriterionRow(criterion: criterion,
                                 score: evaluation.criterionScore(for: criterion.key),
                                 pattern: evaluation.pattern(for: criterion.key))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct CriterionRow: View {
    let criterion: Criterion
    let score: CriterionScore?
    let pattern: EvidencePattern

    private var note: String {
        if let s = score {
            let n = s.note.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty { return n }
            return criterion.rubric.nearestAnchor(for: s.score)
        }
        return "Not scored yet"
    }

    private var proposed: Bool { score?.aiProposed ?? false }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(criterion.title)
                    .font(.system(.subheadline))
                    .foregroundStyle(ForgeColor.ink)
                Text(note)
                    .font(.system(.footnote))
                    .foregroundStyle(ForgeColor.inkSecondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            EvidenceChip(pattern: pattern, size: 22)

            // The gauge: 5pt wide, 32pt tall, filled to score/5.
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 3).fill(ForgeColor.line)
                RoundedRectangle(cornerRadius: 3)
                    .fill(ForgeColor.ink)
                    .frame(height: 32 * CGFloat(score?.score ?? 0) / 5)
            }
            .frame(width: 5, height: 32)
            .accessibilityHidden(true)

            Text(score.map { String($0.score) } ?? "–")
                .font(ForgeType.numeralSmall)
                .foregroundStyle(proposed ? ForgeColor.spark : ForgeColor.ink)
                .frame(width: 22, alignment: .trailing)
        }
        .padding(.vertical, 13)
        .overlay(alignment: .bottom) { Rectangle().fill(ForgeColor.line).frame(height: 1) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(criterion.title), \(score.map { "scored \($0.score) of 5" } ?? "not scored")\(proposed ? ", proposed by the panel" : ""). \(note)")
    }
}
