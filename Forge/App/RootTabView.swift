import SwiftUI
import SwiftData

/// Home · Ideas · Sparks · Plans · Journal (decisions 0025, 0040, 0041), the capture dock on every
/// top-level screen, and the one capture sheet.
struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @Query private var ideas: [Idea]
    @Query private var checks: [RealityCheck]

    var body: some View {
        @Bindable var env = env
        TabView(selection: $env.tab) {
            HomeView()
                .tabItem { Label(ForgeTab.home.title, systemImage: ForgeTab.home.symbol) }
                .badge(env.realityChecks.unseenBriefs.isEmpty ? 0 : env.realityChecks.unseenBriefs.count)
                .tag(ForgeTab.home)
            IdeasView()
                .tabItem { Label(ForgeTab.ideas.title, systemImage: ForgeTab.ideas.symbol) }
                .tag(ForgeTab.ideas)
            SparksView()
                .tabItem { Label(ForgeTab.sparks.title, systemImage: ForgeTab.sparks.symbol) }
                .tag(ForgeTab.sparks)
            PlansView()
                .tabItem { Label(ForgeTab.plans.title, systemImage: ForgeTab.plans.symbol) }
                .tag(ForgeTab.plans)
            NavigationStack {
                JournalView(asTab: true)
                    .captureDock()
                    .forgeDestinations()
            }
            .tabItem { Label(ForgeTab.journal.title, systemImage: ForgeTab.journal.symbol) }
            .tag(ForgeTab.journal)
        }
        .forgeAnimation(ForgeMotion.settle, value: env.tab)
        .sheet(isPresented: $env.showingMembership) { MembershipView() }
        .task { await env.membership.start() }
        // Decision 0043: a plan changed in Settings or Apple's sheet shows up on return.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await env.membership.refresh() } }
        }
        .task { await env.refreshRules() }
        .sheet(item: $env.capture) { request in
            CaptureSheet(autoStartVoice: request == .voice)
        }
        // §7: saving an idea never lands on a static card; Home turns toward it.
        // Decision 0028: the first time, the free-check screen asks first.
        .onChange(of: env.justCapturedIdeaID) { _, id in
            guard let id else { return }
            withAnimation(ForgeMotion.settle) { env.tab = .home }
            if env.firstRun.offersFirstCheck(hasAnyCheck: !checks.isEmpty) {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { env.firstCheckIdeaID = IdeaRef(id: id) }
            }
        }
        .sheet(item: $env.firstCheckIdeaID) { ref in FirstCheckDestination(id: ref.id) }
        .fullScreenCover(isPresented: Binding(
            get: { env.firstRun.showsWelcome(ideasEmpty: ideas.isEmpty) },
            set: { if !$0 { env.firstRun.markWelcomeSeen() } })) {
            WelcomeView()
        }
        // Home Screen quick action "New idea" and the "New hunch" intent, at launch or while running.
        .onAppear { consumeQuickAction() }
        .onChange(of: QuickActions.shared.pending) { _, _ in consumeQuickAction() }
    }

    private func consumeQuickAction() {
        guard let action = QuickActions.shared.take() else { return }
        switch action {
        case .newIdea: env.capture = .text
        case .newHunch: env.capture = .voice
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppEnvironment.live)
        .modelContainer(try! .forge(inMemory: true))
}
