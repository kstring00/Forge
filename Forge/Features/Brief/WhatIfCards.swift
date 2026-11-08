import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0024: "What if…" under the riskiest assumption, when the idea as
/// stated is weak. Each card names the weakness it fixes, why the Library
/// suggests it, and the first test. "Make this its own idea" saves a sibling
/// idea, unchecked; the panel looks at it only through the confirm sheet.
struct WhatIfCards: View {
    let idea: Idea
    let check: RealityCheck
    let evaluation: Evaluation
    @Environment(\.modelContext) private var context
    @State private var opened: Idea?

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("What if…").forgeLabel()
            Text("The Strategist's pivots. Each keeps what scored well and changes one thing the Library gives a reason to change.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            ForEach(check.pivots) { pivot in card(pivot) }
        }
        .navigationDestination(item: $opened) { IdeaDetailView(idea: $0) }
    }

    private func card(_ pivot: PivotIdea) -> some View {
        let spawned = PivotActions.spawnedIdea(for: pivot, of: idea)
        return VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack {
                Text(label(for: pivot)).forgeLabelSmall().foregroundStyle(ForgeColor.emberText)
                Spacer()
                Text(pivot.pivotType.displayName).forgeLabelSmall()
            }
            Text(pivot.whatIf).font(ForgeType.statement).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            Text(pivot.why).font(.system(.footnote)).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            Text("First test: \(pivot.firstTest)").font(.system(.footnote)).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            if !pivot.sourceIDs.isEmpty {
                Text(sourceLine(pivot)).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).lineLimit(2)
            }
            if let spawned {
                Button { opened = spawned } label: {
                    HStack(spacing: 4) {
                        Text("Open the idea").font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.ink)
                        Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    opened = PivotActions.spawn(pivot, from: idea, check: check, in: context)
                } label: {
                    Text("Make this its own idea").frame(maxWidth: .infinity).modifier(SecondaryButtonChrome())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Saves a new idea with this what-if as its text. Nothing is sent to the panel until you ask.")
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private func label(for pivot: PivotIdea) -> String {
        WhatIfPolicy.raisesLabel(criterionTitle: evaluation.lens.criterion(pivot.fixes)?.title ?? pivot.fixes)
    }

    private func sourceLine(_ pivot: PivotIdea) -> String {
        let titles = pivot.sourceIDs.compactMap { id in idea.sources.first { $0.id == id }?.title }
        return titles.isEmpty ? "" : "From: " + titles.prefix(2).joined(separator: " · ")
    }
}

/// Saving a pivot as an idea of its own. Never runs a check.
enum PivotActions {
    /// A sibling idea: the what-if as its own words, the parent as `pivotOf`,
    /// origin pivoted, the parent's lens, stage capture, not yet checked. The
    /// reasoning and first test go in its notes so nothing is lost.
    @discardableResult
    static func spawn(_ pivot: PivotIdea, from parent: Idea, check: RealityCheck, in context: ModelContext) -> Idea {
        if let existing = spawnedIdea(for: pivot, of: parent) { return existing }
        let child = Idea(originalText: pivot.whatIf, origin: .pivoted)
        child.pivotType = pivot.pivotType
        child.lensType = parent.lensType
        child.notes = "Pivot of “\(parent.title)” (\(pivot.pivotType.displayName)). Raises \(pivot.fixes): \(pivot.why)\nFirst test: \(pivot.firstTest)"
        context.insert(child)
        child.pivotOf = parent
        if let i = check.pivots.firstIndex(where: { $0.id == pivot.id }) {
            var updated = check.pivots
            updated[i].spawnedIdeaID = child.id
            check.pivots = updated
        }
        parent.touch()
        try? context.save()
        return child
    }

    /// The idea already made from this pivot, if it still exists.
    static func spawnedIdea(for pivot: PivotIdea, of parent: Idea) -> Idea? {
        guard let id = pivot.spawnedIdeaID else { return nil }
        return parent.pivots.first { $0.id == id }
    }
}
