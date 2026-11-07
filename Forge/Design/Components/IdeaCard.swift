import SwiftUI
import ForgeCore

/// The Vault card. The title is the hero; everything else is quiet.
struct IdeaCard: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .top) {
                Text(idea.title)
                    .font(ForgeType.ideaTitle)
                    .foregroundStyle(ForgeColor.ink)
                    .lineLimit(3)
                Spacer(minLength: ForgeSpacing.s)
                Circle()
                    .fill(ForgeColor.lensTint(idea.lensType))
                    .frame(width: 8, height: 8)
                    .padding(.top, 10)
                    .accessibilityHidden(true)
            }
            HStack(spacing: ForgeSpacing.m) {
                Text(idea.stage.displayName).forgeLabel()
                if let lens = idea.lensType {
                    Text(lens.displayName).forgeLabel()
                }
                if idea.triage?.isComplete == true {
                    Text("Screened").forgeLabel()
                }
                Spacer()
                Text(idea.createdAt, style: .date)
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
            if let evaluation = idea.latestEvaluation {
                HStack(spacing: ForgeSpacing.m) {
                    Text("Potential \(evaluation.potential)").forgeLabel()
                    Text("Confidence \(evaluation.confidence)").forgeLabel()
                }
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous)
                .strokeBorder(ForgeColor.line, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
    }
}
