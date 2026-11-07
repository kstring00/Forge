import SwiftUI
import SwiftData
import ForgeCore

/// §7 v4.1: the panel's desk. The orbs, one card, the capture field, recent
/// ideas. No stats, no streaks, no charts, no tour: the orbs are the introduction.
struct HomeView: View {
    let onCapture: () -> Void

    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \Idea.createdAt, order: .reverse) private var ideas: [Idea]
    @Query(filter: #Predicate<Project> { $0.statusRaw == "active" }) private var activeProjects: [Project]

    private var live: [Idea] { ideas.filter { !$0.isArchived } }
    private var card: HomeCard {
        HomeCard.choose(justCaptured: env.justCapturedIdeaID, ideas: ideas, projects: activeProjects, unseenBriefs: env.realityChecks.unseenBriefs,
                        failedChecks: Set(env.realityChecks.failures.keys))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    if live.isEmpty {
                        EmptyPanel()
                        QuickCaptureField(focusOnAppear: true)
                    } else {
                        PanelHeader(ideas: ideas)
                        theCard
                        QuickCaptureField()
                        recent
                    }
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xxl)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ForgeColor.canvas)
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink { SettingsView() } label: {
                        Image(systemName: "gearshape").accessibilityLabel("Settings")
                    }
                }
            }
            .forgeDestinations()
        }
    }

    // MARK: The one card

    @ViewBuilder
    private var theCard: some View {
        switch card {
        case .afterCapture(let id):
            if let idea = ideas.first(where: { $0.id == id }) { AfterCaptureCard(idea: idea) }
        case .briefReady(let id):
            if let idea = ideas.first(where: { $0.id == id }), let check = idea.latestRealityCheck {
                NavigationLink(value: VaultRoute.idea(id)) {
                    cardChrome(ember: true) {
                        Text("Brief ready").forgeLabel().foregroundStyle(Color(red: 1.0, green: 0.886, blue: 0.839))
                        Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(.white)
                        Text("\(check.verdict.displayName). \(check.summary)").font(.system(size: 14)).foregroundStyle(.white.opacity(0.9)).lineLimit(3)
                    }
                }
                .buttonStyle(.plain)
            }
        case .nextStep(let pid):
            if let project = activeProjects.first(where: { $0.id == pid }), let step = project.nextStep {
                NavigationLink(value: WorkshopRoute.project(pid)) {
                    cardChrome(ember: false) {
                        Text("Next step").forgeLabel()
                        Text(step).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                        Text(project.name).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
                .buttonStyle(.plain)
            }
        case .unchecked(let id):
            if let idea = ideas.first(where: { $0.id == id }) { UncheckedCard(idea: idea) }
        case .none:
            EmptyView()
        }
    }

    private var recent: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Recently captured").forgeLabel()
            ForEach(live.prefix(5)) { idea in
                NavigationLink(value: VaultRoute.idea(idea.id)) {
                    IdeaCard(idea: idea, status: IdeaStatus.of(idea, checking: env.realityChecks.isRunning(idea.id), failed: env.realityChecks.failure(for: idea.id) != nil), compact: true)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardChrome<Content: View>(ember: Bool, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: ForgeSpacing.xs) { content() }
            Spacer()
            Image(systemName: "arrow.right").foregroundStyle(ember ? .white : ForgeColor.ink)
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ember ? ForgeColor.ember : ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ember ? Color.clear : ForgeColor.line))
    }
}

/// §7 after capture: the orbs turn toward the new idea. One tap to working.
struct AfterCaptureCard: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env

    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
            if runner.isRunning {
                HStack(spacing: ForgeSpacing.s) {
                    ProgressView().controlSize(.small)
                    Text("Working. The orbs above show who is on it.").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                }
            } else {
                Text(Spheres.afterCaptureLine).font(ForgeType.statement).foregroundStyle(ForgeColor.ink)
                RealityCheckButton(idea: idea)
                HStack {
                    Spacer()
                    Button("Later") { env.justCapturedIdeaID = nil }
                        .font(.caption.weight(.medium)).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .onChange(of: runner.isRunning) { _, running in
            if running { env.justCapturedIdeaID = nil }
        }
    }
}

/// The most recent unchecked idea, with the Reality Check button on the card.
struct UncheckedCard: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            NavigationLink(value: VaultRoute.idea(idea.id)) {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    HStack(spacing: ForgeSpacing.s) {
                        SphereDots(lit: [])
                        Text(env.realityChecks.failure(for: idea.id) == nil ? "Not yet checked" : "Last check failed").forgeLabel()
                    }
                    Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                    OriginalText(text: idea.originalText).lineLimit(3)
                }
            }
            .buttonStyle(.plain)
            RealityCheckButton(idea: idea, compact: true)
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }
}
