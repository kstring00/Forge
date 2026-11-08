import SwiftUI
import SwiftData
import ForgeCore

/// The Formation tab: checked ideas, where the panel has weighed in and the
/// user rules. Each row leads with the six orbs in their verdict states.
struct FormationView: View {
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    private var inFormation: [Idea] { ideas.filter { $0.track == .formation } }

    var body: some View {
        NavigationStack {
            Group {
                if inFormation.isEmpty {
                    EmptyState(symbol: ForgeTab.formation.symbol,
                               title: "Nothing in formation",
                               message: "Send an idea to the panel. When it comes back with a verdict, it sits here until you rule and take a step.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ForgeSpacing.m) {
                            Text(Track.formation.tagline).font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)
                            ForEach(inFormation) { idea in
                                NavigationLink(value: VaultRoute.idea(idea.id)) {
                                    FormationRow(idea: idea, checking: env.realityChecks.isRunning(idea.id))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(ForgeSpacing.m)
                        .padding(.bottom, ForgeSpacing.xxl)
                    }
                }
            }
            .background(ForgeColor.canvas)
            .navigationTitle(Track.formation.displayName)
            .forgeDestinations()
        }
    }
}

/// A checked idea: mini orbs in their verdict states, the verdict word, the
/// serif title, and where the rulings stand.
struct FormationRow: View {
    let idea: Idea
    var checking = false

    private var round: Round? { idea.rounds.max { $0.createdAt < $1.createdAt } }
    private var verdicts: [Verdict] { round?.verdicts ?? [] }
    private var tally: RoundTally { RoundTally(verdicts.map { ($0.sphere, $0.kind, $0.ruling?.choice) }) }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            IdeaSpark(idea: idea, size: 44)
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                HStack(spacing: 8) {
                    Text(Track.formation.displayName).forgeLabelSmall().foregroundStyle(Color(hex: 0x8B63C9))
                    Spacer(minLength: 8)
                    StageTrail(track: idea.track)
                }
                Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink).lineLimit(2)
                HStack(spacing: 6) {
                    if let check = idea.latestRealityCheck, !checking {
                        Text(check.verdict.displayName).font(.system(size: 12, weight: .medium)).foregroundStyle(ForgeColor.emberText)
                        Text("·").forgeLabelSmall()
                    }
                    Text(statusLine).forgeLabelSmall()
                }
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .combine)
    }

    var statusLine: String {
        if checking { return "The panel is on it" }
        if idea.project != nil { return "Ruled · step in Reality" }
        if tally.total == 0 { return idea.latestEvaluation == nil ? "Not yet checked" : "Scored by hand" }
        var parts = [tally.isComplete ? "Ruled" : "\(tally.ruled) of \(tally.total) ruled"]
        if !tally.splits.isEmpty { parts.append(tally.splits.count == 1 ? "1 split" : "\(tally.splits.count) splits") }
        return parts.joined(separator: " · ")
    }
}
