import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0041: the Plans tab. Every launch plan, newest first, then the
/// ideas the panel has looked at that could have one.
struct PlansView: View {
    @Query(sort: \Idea.updatedAt, order: .reverse) private var ideas: [Idea]

    private var withPlans: [Idea] { ideas.filter { !$0.isArchived && $0.launchPlanData != nil } }
    private var ready: [Idea] { ideas.filter { PlanBuilder.isEligible($0) && $0.launchPlanData == nil } }

    var body: some View {
        NavigationStack {
            Group {
                if withPlans.isEmpty && ready.isEmpty {
                    EmptyState(symbol: ForgeTab.plans.symbol,
                               title: "No plans yet",
                               message: "Once the panel has looked at an idea, Hunch can turn everything it knows into a short launch plan: what's proven, the first 90 days, the money, and when to stop.")
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: ForgeSpacing.l) {
                            Text("A short plan for any idea the panel has looked at, built only from what Hunch knows. Anything without a source is marked as a belief.")
                                .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                            if !withPlans.isEmpty {
                                VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                                    Text("Your plans").forgeLabel()
                                    ForEach(withPlans) { PlanRow(idea: $0) }
                                }
                            }
                            if !ready.isEmpty {
                                VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                                    Text("Ready for a plan").forgeLabel()
                                    ForEach(ready) { ReadyForPlanCard(idea: $0) }
                                }
                            }
                            Text("A plan is \(PlanCost.newPlan) checks; bringing one up to date is \(PlanCost.refresh). Plans are included in Pro. A plan that fails costs nothing.")
                                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(ForgeSpacing.m)
                        .padding(.bottom, ForgeSpacing.dockClearance)
                    }
                }
            }
            .captureDock()
            .background(ForgeColor.canvas)
            .navigationTitle(ForgeTab.plans.title)
            .forgeDestinations()
        }
    }
}

/// A plan in the list: the idea, its one line, when, and what moved since.
private struct PlanRow: View {
    let idea: Idea

    var body: some View {
        if let plan = idea.launchPlan {
            let changes = PlanBuilder.changes(since: plan, for: idea)
            NavigationLink(value: LabRoute.plan(ideaID: idea.id)) {
                HStack(alignment: .top, spacing: 12) {
                    IdeaSpark(idea: idea, size: 32)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(idea.title).font(ForgeType.subhead).foregroundStyle(ForgeColor.ink).lineLimit(2)
                        Text(plan.oneLine).font(.subheadline).foregroundStyle(ForgeColor.inkSecondary).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Updated \(LaunchPlanView.when(plan.createdAt)) · \(ProofStage.of(idea).cardWord)").forgeLabelSmall()
                        if !changes.isEmpty {
                            Text("Since then: \(changes.joined(separator: ", "))")
                                .font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.emberText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary).padding(.top, 4)
                }
                .padding(ForgeSpacing.cardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}

/// An idea the panel has looked at, with no plan yet.
private struct ReadyForPlanCard: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            NavigationLink(value: VaultRoute.idea(idea.id)) {
                HStack(spacing: 12) {
                    IdeaSpark(idea: idea, size: 32)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(idea.title).font(ForgeType.subhead).foregroundStyle(ForgeColor.ink).lineLimit(2)
                        Text(ProofStage.of(idea).cardWord).forgeLabelSmall()
                    }
                    Spacer()
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            MakePlanButton(idea: idea, prominent: true)
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}

/// "Make a launch plan · 3 checks", or "Bring the plan up to date · 1 check".
/// Asks first (what is sent, what it costs), then writes the plan in the
/// background. Out of checks opens Membership.
struct MakePlanButton: View {
    let idea: Idea
    /// Orange when it is the card's one primary action.
    var prominent = false
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @State private var confirming = false

    private var refreshing: Bool { idea.launchPlanData != nil }
    private var title: String {
        "\(refreshing ? "Bring the plan up to date" : "Make a launch plan") · \(env.plans.costLabel(for: idea))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if env.plans.isRunning(idea.id) {
                HStack(spacing: ForgeSpacing.s) {
                    ProgressView().controlSize(.small)
                    Text(refreshing ? "Bringing the plan up to date…" : "The panel is writing the plan…")
                        .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                }
                .frame(minHeight: 44)
            } else {
                Button { start() } label: {
                    if prominent { PrimaryButtonLabel(title: title) } else { SecondaryButtonLabel(title: title) }
                }
                .buttonStyle(.plain)
            }
            if let failure = env.plans.failure(for: idea.id) {
                Text(failure).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $confirming) {
            AIConfirmSheet(content: .launchPlan(ideaTitle: idea.title, refreshing: refreshing, allowance: allowance)) { send in
                if send { env.plans.build(idea, in: context) }
            }
        }
    }

    private var allowance: String {
        let cost = env.plans.cost(for: idea)
        if cost == 0 { return "Included in Pro" }
        let left = env.entitlements.balance.total
        return "Uses \(cost) \(cost == 1 ? "check" : "checks") · you have \(left)"
    }

    private func start() {
        env.plans.dismissFailure(idea.id)
        if !env.plans.canAfford(idea) {
            env.showingMembership = true
            return
        }
        confirming = true
    }
}

extension AIConfirmSheet.Content {
    static func launchPlan(ideaTitle: String, refreshing: Bool, allowance: String) -> Self {
        .init(kind: "Launch plan",
              title: refreshing ? "Bring the plan for \(ideaTitle) up to date?" : "Make a launch plan for \(ideaTitle)?",
              whatHappens: "The panel turns what Hunch knows about this idea (its sources, the panel's take and the conversations you logged) into a short plan: what's proven, the first 90 days, the money, and when to stop. Anything without a source is marked as a belief.",
              duration: "Takes about a minute.",
              sendTitle: refreshing ? "Update the plan" : "Make the plan",
              allowance: allowance)
    }
}

/// On the idea's page: its plan, or the way to make one.
struct PlanEntryCard: View {
    let idea: Idea

    var body: some View {
        if let plan = idea.launchPlan {
            NavigationLink(value: LabRoute.plan(ideaID: idea.id)) {
                HStack(spacing: 12) {
                    Image(systemName: ForgeTab.plans.symbol).font(.title3).foregroundStyle(ForgeColor.emberText)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Launch plan").forgeLabelSmall()
                        Text(plan.oneLine).font(.subheadline).foregroundStyle(ForgeColor.ink).lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Updated \(LaunchPlanView.when(plan.createdAt))").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    }
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary)
                }
                .padding(ForgeSpacing.m)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if PlanBuilder.isEligible(idea) {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text("Launch plan").forgeLabelSmall()
                Text("Turn what Hunch knows into a short plan: what's proven, the first 90 days, the money, and when to stop.")
                    .font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                MakePlanButton(idea: idea)
            }
            .padding(ForgeSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3])))
        }
    }
}
