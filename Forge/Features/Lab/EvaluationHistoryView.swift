import SwiftUI
import ForgeCore

/// Every version, newest first. Earlier versions are read-only by construction.
struct EvaluationHistoryView: View {
    let idea: Idea

    private var versions: [Evaluation] { idea.evaluations.sorted { $0.version > $1.version } }
    private var takes: [RealityCheck] { PanelsTake.history(for: idea) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                if !takes.isEmpty {
                    Text("The panel's takes").forgeLabel()
                    ForEach(takes) { c in take(c, current: c.id == takes.first?.id) }
                    Text("Versions").forgeLabel().padding(.top, ForgeSpacing.s)
                }
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

    /// One take: the verdict word, when, and the summary. A re-check adds a new one above.
    private func take(_ c: RealityCheck, current: Bool) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            HStack {
                Text(c.verdict.displayName).font(.system(size: 15, weight: .medium)).foregroundStyle(ForgeColor.ink)
                Spacer()
                Text(current ? "Current" : c.createdAt.formatted(date: .abbreviated, time: .omitted)).forgeLabel()
            }
            if current {
                Text(c.createdAt.formatted(date: .abbreviated, time: .shortened)).font(.caption2).foregroundStyle(ForgeColor.inkSecondary)
            }
            if !c.summary.isEmpty {
                Text(c.summary).font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary).lineLimit(4)
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(current ? ForgeColor.ember.opacity(0.6) : ForgeColor.line))
    }

    private func figure(_ value: Int, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)").font(ForgeType.numeralSmall).foregroundStyle(ForgeColor.ink)
            Text(label).forgeLabelSmall()
        }
    }
}
