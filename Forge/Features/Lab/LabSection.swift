import SwiftUI
import SwiftData
import ForgeCore

/// The Evaluation Lab inside idea detail, in the canvas's order: rings, pattern
/// legend, Projection card, criteria rows, ladder card, riskiest assumption,
/// Next move, then Run a Round / Reality Check, then the Library line.
/// Before any evaluation exists it is a single entry card.
struct LabSection: View {
    @Bindable var idea: Idea
    @Environment(\.modelContext) private var context
    @State private var showingTriage = false
    @State private var confirmingNewVersion = false

    private var evaluation: Evaluation? { idea.latestEvaluation }

    var body: some View {
        if let evaluation {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                versionLine(evaluation)
                RingsRow(evaluation: evaluation)
                PatternLegend(breakdown: evaluation.confidenceBreakdown)
                ProjectionCard(evaluation: evaluation)
                CriteriaList(evaluation: evaluation)
                LadderCard(evaluation: evaluation)
                RiskiestAssumptionBlock(evaluation: evaluation)
                NextMoveButton(evaluation: evaluation)
                RoundRealityRow(idea: idea)
                libraryLine
            }
            .confirmationDialog("Start version \(evaluation.version + 1)?", isPresented: $confirmingNewVersion, titleVisibility: .visible) {
                Button("Start from v\(evaluation.version)'s scores") {
                    idea.beginEvaluation(lens: evaluation.lensType, copying: evaluation)
                }
                Button("Start blank") {
                    idea.beginEvaluation(lens: evaluation.lensType)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Version \(evaluation.version) is kept exactly as it is.")
            }
        } else if !idea.isArchived {
            entryCard
                .sheet(isPresented: $showingTriage) {
                    OpportunityFilterSheet(idea: idea) {
                        idea.beginEvaluation(lens: .business)
                    }
                }
        }
    }

    // MARK: Entry

    private var entryCard: some View {
        Button {
            showingTriage = true
        } label: {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    Text("Evaluate").forgeLabel()
                    Text("Screen it in sixty seconds, then score it against the Business criteria (the lens).")
                        .font(ForgeType.body)
                        .foregroundStyle(ForgeColor.ink)
                    Text("Ten yes/no questions first. They surface red flags before you spend an hour scoring.")
                        .font(.footnote)
                        .foregroundStyle(ForgeColor.inkSecondary)
                }
                Spacer()
                Image(systemName: "arrow.right").foregroundStyle(ForgeColor.ink)
            }
            .padding(ForgeSpacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Evaluate this idea")
    }

    // MARK: Version line

    private func versionLine(_ e: Evaluation) -> some View {
        HStack {
            Text("v\(e.version) · \(e.isFinal ? "Final" : "\(e.scoredCount) of \(e.lens.criteria.count) scored")").forgeLabel()
            Spacer()
            if idea.evaluations.count > 1 {
                NavigationLink(value: LabRoute.history(ideaID: idea.id)) {
                    Text("History").forgeLabel()
                }
            }
            Menu {
                if !e.isFinal {
                    Button {
                        try? e.finalize()
                    } label: { Label("Finalize v\(e.version)", systemImage: "lock") }
                    .disabled(!e.isComplete)
                }
                Button {
                    confirmingNewVersion = true
                } label: { Label("New version", systemImage: "plus.square.on.square") }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundStyle(ForgeColor.inkSecondary)
                    .accessibilityLabel("Evaluation options")
            }
        }
    }

    private var libraryLine: some View {
        HStack {
            Text("Library · \(idea.sources.count) \(idea.sources.count == 1 ? "source" : "sources")").forgeLabel()
            Spacer()
            Text("Phase 4")
                .font(.footnote)
                .foregroundStyle(ForgeColor.inkSecondary)
        }
    }
}
