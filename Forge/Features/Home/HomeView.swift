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
        HomeCard.choose(justCaptured: env.justCapturedIdeaID, ideas: ideas, projects: activeProjects, unseenBriefs: env.realityChecks.unseenBriefs)
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
                    IdeaCard(idea: idea, status: IdeaStatus.of(idea, checking: env.realityChecks.isRunning(idea.id)), compact: true)
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
    @AppStorage(AIConsent.storageKey) private var consentStamp: Double = 0

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
                    Text(estimateLine).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    Spacer()
                    Button("Later") { env.justCapturedIdeaID = nil }
                        .font(.caption.weight(.medium)).foregroundStyle(ForgeColor.inkSecondary)
                }
                if case .offline(let m) = runner.phase { Text(m).font(.caption).foregroundStyle(ForgeColor.inkSecondary) }
                if case .failed(let m) = runner.phase { Text(m).font(.caption).foregroundStyle(ForgeColor.inkSecondary) }
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .task { await runner.loadEstimate() }
        .onChange(of: runner.isRunning) { _, running in
            if running { env.justCapturedIdeaID = nil }
        }
    }

    private var estimateLine: String {
        let e = runner.estimate
        return consentStamp > 0
            ? "About \(AISpend.format(e.lowerBound)) to \(AISpend.format(e.upperBound))."
            : "About \(AISpend.format(e.lowerBound)) to \(AISpend.format(e.upperBound)). The first run asks before sending your idea text to the AI through your proxy."
    }
}

/// The most recent unchecked idea, with the Reality Check button on the card.
struct UncheckedCard: View {
    let idea: Idea

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            NavigationLink(value: VaultRoute.idea(idea.id)) {
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    HStack(spacing: ForgeSpacing.s) { SphereDots(lit: []); Text("Not yet checked").forgeLabel() }
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

/// The ember Reality Check button, shared by Home cards and idea detail.
/// Handles consent on first use and the monthly ceiling, then hands the run
/// to the app-level center so it survives navigation.
struct RealityCheckButton: View {
    let idea: Idea
    var compact = false
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @State private var showingConsent = false
    @State private var pending = false

    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            Button { tap() } label: {
                HStack(alignment: .center, spacing: ForgeSpacing.m) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Reality check").font(ForgeType.label).textCase(.uppercase).kerning(1.3).foregroundStyle(Color(red: 1.0, green: 0.886, blue: 0.839))
                        if !compact {
                            Text("Who already does this, what they charge, what people complain about, and what the panel makes of it.")
                                .font(.system(size: 15)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                    HStack(spacing: -6) { ForEach(Sphere.phase3Panel.prefix(3)) { SphereOrb(sphere: $0, size: 18) } }
                }
                .padding(compact ? 14 : 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(runner.isRunning)
            .accessibilityLabel("Run a Reality Check")
            if case .overCeiling(let estimate, let remaining) = runner.phase {
                Text("This check could cost about \(AISpend.format(estimate)); \(AISpend.format(remaining)) is left under this month's ceiling. Raise it in Settings.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
        .sheet(isPresented: $showingConsent) {
            AIConsentSheet { agreed in
                showingConsent = false
                if agreed {
                    AIConsent.grant()
                    if pending { pending = false; start() }
                } else {
                    pending = false
                }
            }
        }
    }

    private func tap() {
        guard AIConsent.isGranted else {
            pending = true
            showingConsent = true
            return
        }
        start()
    }

    private func start() {
        let advantages = (try? context.fetch(FetchDescriptor<Advantage>()))?.map(\.text) ?? []
        let constraints = (try? context.fetch(FetchDescriptor<Constraint>()))?.map(\.text) ?? []
        env.realityChecks.start(idea: idea, context: context, advantages: advantages, constraints: constraints)
    }
}
