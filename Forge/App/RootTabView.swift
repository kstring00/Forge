import SwiftUI

/// Home · Ideas · Journal (decision 0025), the capture dock on every
/// top-level screen, and the one capture sheet.
struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env

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
            NavigationStack {
                JournalView(asTab: true)
                    .captureDock()
                    .forgeDestinations()
            }
            .tabItem { Label(ForgeTab.journal.title, systemImage: ForgeTab.journal.symbol) }
            .tag(ForgeTab.journal)
        }
        .forgeAnimation(ForgeMotion.settle, value: env.tab)
        .sheet(item: $env.capture) { request in
            CaptureSheet(autoStartVoice: request == .voice)
        }
        // §7: saving an idea never lands on a static card; Home turns toward it.
        .onChange(of: env.justCapturedIdeaID) { _, id in
            if id != nil { withAnimation(ForgeMotion.settle) { env.tab = .home } }
        }
        // Home Screen quick action "New idea", at launch or while running.
        .onAppear { consumeQuickAction() }
        .onChange(of: QuickActions.shared.pending) { _, _ in consumeQuickAction() }
    }

    private func consumeQuickAction() {
        guard let action = QuickActions.shared.take() else { return }
        switch action {
        case .newIdea: env.capture = .text
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppEnvironment.live)
        .modelContainer(try! .forge(inMemory: true))
}
