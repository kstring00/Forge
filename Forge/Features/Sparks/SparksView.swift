import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0040: Sparks. Every "What if…" the panel has offered, across all
/// ideas, newest check first. Free on every plan. One tap makes a Spark an
/// idea of its own (unchecked; the panel looks at it only when asked).
struct SparksView: View {
    @Query(sort: \RealityCheck.createdAt, order: .reverse) private var checks: [RealityCheck]

    /// The latest check per live idea, and its Sparks.
    private var groups: [(idea: Idea, check: RealityCheck)] {
        var seen = Set<UUID>()
        var out: [(Idea, RealityCheck)] = []
        for c in checks {
            guard let idea = c.idea, !idea.isArchived, !c.pivots.isEmpty, !seen.contains(idea.id) else { continue }
            seen.insert(idea.id)
            out.append((idea, c))
        }
        return out
    }

    private var count: Int { groups.reduce(0) { $0 + $1.check.pivots.count } }

    var body: some View {
        NavigationStack {
            Group {
                if groups.isEmpty {
                    EmptyState(symbol: ForgeTab.sparks.symbol,
                               title: "No Sparks yet",
                               message: "Every time the panel looks at an idea, it comes back with two or three \u{201C}What if…\u{201D} ideas: a sharper customer, a better channel, a different model. They land here, free.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ForgeSpacing.l) {
                            Text("\(count) \(count == 1 ? "way" : "ways") the panel thinks your ideas could be stronger. Make any one its own idea.")
                                .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(groups, id: \.check.id) { g in
                                SparkGroup(idea: g.idea, check: g.check)
                            }
                        }
                        .padding(ForgeSpacing.m)
                        .padding(.bottom, ForgeSpacing.dockClearance)
                    }
                }
            }
            .captureDock()
            .background(ForgeColor.canvas)
            .navigationTitle(ForgeTab.sparks.title)
            .forgeDestinations()
        }
    }
}

/// One idea's Sparks under its title, which opens its Brief.
private struct SparkGroup: View {
    let idea: Idea
    let check: RealityCheck

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            NavigationLink(value: LabRoute.brief(ideaID: idea.id)) {
                HStack(spacing: 10) {
                    IdeaSpark(idea: idea, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("From").forgeLabelSmall()
                        Text(idea.title).font(ForgeType.subhead).foregroundStyle(ForgeColor.ink).lineLimit(2)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            ForEach(check.pivots) { pivot in SparkCard(idea: idea, check: check, pivot: pivot) }
        }
    }
}

/// A Spark: the what-if in serif, the weakness it raises, why, the first test,
/// and making it an idea of its own.
private struct SparkCard: View {
    let idea: Idea
    let check: RealityCheck
    let pivot: PivotIdea
    @Environment(\.modelContext) private var context

    private var spawned: Idea? { PivotActions.spawnedIdea(for: pivot, of: idea) }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .top) {
                SparkGlyph().padding(.top, 4)
                Text(pivot.whatIf)
                    .font(Font.custom("Fraunces-Italic", size: 19, relativeTo: .title3))
                    .foregroundStyle(ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text("Raises \(Lenses.criterion(pivot.fixes, in: idea.lensType ?? .business)?.title ?? pivot.fixes) · \(pivot.pivotType.displayName)")
                .forgeLabelSmall().fixedSize(horizontal: false, vertical: true)
            Text(pivot.why).font(.subheadline).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            Text("First test: \(pivot.firstTest)").font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            if let spawned {
                NavigationLink(value: VaultRoute.idea(spawned.id)) { SecondaryButtonLabel(title: "Open the idea") }
                    .buttonStyle(.plain)
            } else {
                Button {
                    PivotActions.spawn(pivot, from: idea, check: check, in: context)
                } label: { PrimaryButtonLabel(title: "Make this its own idea") }
                    .buttonStyle(.plain)
                    .accessibilityHint("Saves it as a new idea. Nothing is sent to the panel until you ask.")
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}
