import SwiftUI

/// Every AI write goes through this: the proposal in full, next to the user's
/// own words, saved only on Accept.
struct AIProposalSheet: View {
    let proposal: AIProposal
    let idea: Idea
    var onAccept: () -> Void
    var onDiscard: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    HStack(spacing: ForgeSpacing.xs) {
                        SparkGlyph()
                        Text("Proposed by AI").forgeLabel()
                    }
                    Text("Nothing is saved until you accept. Your original text never changes either way.")
                        .font(.footnote)
                        .foregroundStyle(ForgeColor.inkSecondary)

                    if proposal.kind == .expand {
                        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                            Text("Your original").forgeLabel()
                            OriginalText(text: idea.originalText)
                        }
                    }

                    ForEach(proposal.sections) { section in
                        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                            Text(section.label).forgeLabel()
                            Text(section.text)
                                .font(ForgeType.body)
                                .foregroundStyle(ForgeColor.spark)
                                .textSelection(.enabled)
                        }
                        .padding(ForgeSpacing.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
                    }

                    if !proposal.rationale.isEmpty {
                        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                            Text("Why").forgeLabel()
                            Text(proposal.rationale)
                                .font(ForgeType.aiText)
                                .foregroundStyle(ForgeColor.inkSecondary)
                        }
                    }
                }
                .padding(ForgeSpacing.m)
            }
            .background(ForgeColor.canvas)
            .navigationTitle(proposal.kind == .expand ? "Expand" : "Summarize")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard") { onDiscard(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Accept") { onAccept(); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled()
    }
}
