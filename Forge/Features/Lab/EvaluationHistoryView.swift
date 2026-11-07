import SwiftUI
import ForgeCore

/// Every version, newest first. Earlier versions are read-only by construction.
struct EvaluationHistoryView: View {
    let idea: Idea

    private var versions: [Evaluation] { idea.evaluations.sorted { $0.version > $1.version } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                ForEach(versions) { e in
                    VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                        HStack {
                            Text("v\(e.version) · \(e.lensType.displayName)").forgeLabel()
                            Spacer()
                            Text(e.isFinal ? "Final" : "Open").forgeLabel()
                        }
                        HStack(spacing: ForgeSpacing.l) {
                            figure(e.potential, "Potential")
                            figure(e.confidence, "Confidence")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(e.effectiveMove.displayName).font(.system(size: 13)).foregroundStyle(ForgeColor.ink)
                                Text(e.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.caption2).foregroundStyle(ForgeColor.inkSecondary)
                            }
                        }
                        HStack(spacing: ForgeSpacing.s) {
                            ForEach(e.lens.criteria) { c in
                                VStack(spacing: 2) {
                                    Text(e.criterionScore(for: c.key).map { String($0.score) } ?? "–")
                                        .font(ForgeType.numeralTiny).foregroundStyle(ForgeColor.ink)
                                    Text(c.key).font(.system(size: 9, design: .monospaced)).foregroundStyle(ForgeColor.inkSecondary)
                                }
                            }
                        }
                        if !e.riskiestAssumption.isEmpty {
                            Text(e.riskiestAssumption).font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)
                        }
                    }
                    .padding(ForgeSpacing.cardPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
                }
            }
            .padding(ForgeSpacing.m)
        }
        .background(ForgeColor.canvas)
        .navigationTitle("Versions")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func figure(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.ink)
            Text(label).forgeLabelSmall()
        }
    }
}
