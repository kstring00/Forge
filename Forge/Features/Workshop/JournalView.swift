import SwiftUI
import SwiftData

/// Every decision, newest first, with what was expected and what happened.
/// Shown only when opened. Never scores the user.
struct JournalView: View {
    /// As the Journal tab (decision 0025): a large title and "Your patterns" as a row at the top.
    var asTab = false
    @Query(sort: \Decision.date, order: .reverse) private var decisions: [Decision]
    @State private var recording: Decision?
    @State private var settlingIdea: Idea?
    @State private var settlingText = ""

    var body: some View {
        Group {
            if decisions.isEmpty && !asTab {
                EmptyState(symbol: "book.closed",
                           title: "Nothing decided yet",
                           message: "When you commit to an idea or record what happened, it lands here next to what you expected.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ForgeSpacing.s) {
                        if asTab {
                            NavigationLink { PatternsView() } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Your patterns").font(.system(size: 15, weight: .medium)).foregroundStyle(ForgeColor.ink)
                                        Text("Your record against the panel, and what it knows about you.").font(.system(size: 12)).foregroundStyle(ForgeColor.inkSecondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                                }
                                .modifier(SecondaryButtonChrome())
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, ForgeSpacing.s)
                            if decisions.isEmpty {
                                Text("When you commit to an idea or record what happened, it lands here next to what you expected.")
                                    .font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)
                            }
                        }
                        ForEach(decisions) { d in
                            JournalRow(decision: d, showsContext: true) { recording = d }
                        }
                    }
                    .padding(ForgeSpacing.m)
                    .padding(.bottom, ForgeSpacing.xxl)
                }
            }
        }
        .background(ForgeColor.canvas)
        .navigationTitle("Journal")
        .navigationBarTitleDisplayMode(asTab ? .large : .inline)
        .toolbar {
            if !asTab {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { PatternsView() } label: {
                        Image(systemName: "chart.dots.scatter").accessibilityLabel("Your patterns")
                    }
                }
            }
        }
        .sheet(item: $recording) { d in
            OutcomeSheet(title: "Outcome", subject: d.decision) { happened, _ in
                d.recordOutcome(happened)
                if let idea = d.idea ?? d.project?.idea, !RulingActions.unsettled(on: idea).isEmpty {
                    settlingText = happened
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { settlingIdea = idea }
                }
            }
        }
        .sheet(item: $settlingIdea) { idea in
            SettleRulingsSheet(idea: idea, whatHappened: settlingText)
        }
    }
}
