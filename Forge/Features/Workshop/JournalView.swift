import SwiftUI
import SwiftData

/// Every decision, newest first, with what was expected and what happened.
/// Shown only when opened. Never scores the user.
struct JournalView: View {
    @Query(sort: \Decision.date, order: .reverse) private var decisions: [Decision]
    @State private var recording: Decision?
    @State private var settlingIdea: Idea?
    @State private var settlingText = ""

    var body: some View {
        Group {
            if decisions.isEmpty {
                EmptyState(symbol: "book.closed",
                           title: "Nothing decided yet",
                           message: "When you commit to an idea or record what happened, it lands here next to what you expected.")
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ForgeSpacing.s) {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { PatternsView() } label: {
                    Image(systemName: "chart.dots.scatter").accessibilityLabel("Your patterns")
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
