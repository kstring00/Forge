import SwiftUI
import SwiftData

/// Every idea, as cards. Search, filter and sort arrive in Phase 1.
struct VaultView: View {
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]

    private var live: [Idea] { ideas.filter { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            Group {
                if live.isEmpty {
                    EmptyState(symbol: "archivebox",
                               title: "Nothing in the Vault yet",
                               message: "Every idea you capture lands here, with its original wording kept exactly as you wrote it.")
                } else {
                    ScrollView {
                        LazyVStack(spacing: ForgeSpacing.m) {
                            ForEach(live) { idea in
                                NavigationLink(value: VaultRoute.idea(idea.id)) {
                                    IdeaCard(idea: idea)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(ForgeSpacing.m)
                        .padding(.bottom, ForgeSpacing.xxl * 2)
                    }
                }
            }
            .background(ForgeColor.canvas)
            .navigationTitle("Vault")
            .navigationDestination(for: VaultRoute.self) { route in
                switch route {
                case .idea(let id):
                    if let idea = ideas.first(where: { $0.id == id }) {
                        IdeaDetailView(idea: idea)
                    } else {
                        EmptyState(symbol: "questionmark", title: "Idea not found", message: "It may have been removed.")
                    }
                }
            }
        }
    }
}

/// Phase 0 detail: the original text, visibly immutable. Phase 1 adds the rest.
struct IdeaDetailView: View {
    let idea: Idea

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                GrainGradient(colors: ForgeColor.headerGradient(idea.lensType))
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                Text(idea.title)
                    .font(ForgeType.ideaTitleHero)
                    .foregroundStyle(ForgeColor.ink)
                HStack(spacing: ForgeSpacing.m) {
                    Text(idea.stage.displayName).forgeLabel()
                    Text(idea.createdAt, style: .date).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
                VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                    HStack {
                        Text("Original").forgeLabel()
                        Image(systemName: "lock")
                            .font(.caption2)
                            .foregroundStyle(ForgeColor.inkSecondary)
                            .accessibilityLabel("Cannot be edited")
                    }
                    Text(idea.originalText)
                        .font(ForgeType.body)
                        .foregroundStyle(ForgeColor.ink)
                        .textSelection(.enabled)
                }
                if let summary = idea.aiSummary, idea.aiSummaryConfirmed {
                    AIText(text: summary)
                }
            }
            .padding(ForgeSpacing.m)
        }
        .background(ForgeColor.canvas)
        .navigationBarTitleDisplayMode(.inline)
    }
}
