import SwiftUI

/// Home · Idea · Formation · Reality (brief v4.2 §2). One tab per track.
struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var showingCapture = false

    var body: some View {
        @Bindable var env = env
        TabView(selection: $env.tab) {
            HomeView(onCapture: { showingCapture = true })
                .tabItem { Label(ForgeTab.home.title, systemImage: ForgeTab.home.symbol) }
                .badge(env.realityChecks.unseenBriefs.isEmpty ? 0 : env.realityChecks.unseenBriefs.count)
                .tag(ForgeTab.home)
            // Home has its own capture field; the Idea list carries the floating
            // button itself, so it never follows the user into an idea.
            VaultView(onCapture: { showingCapture = true })
                .tabItem { Label(ForgeTab.idea.title, systemImage: ForgeTab.idea.symbol) }
                .tag(ForgeTab.idea)
            FormationView()
                .tabItem { Label(ForgeTab.formation.title, systemImage: ForgeTab.formation.symbol) }
                .tag(ForgeTab.formation)
            WorkshopView()
                .tabItem { Label(ForgeTab.reality.title, systemImage: ForgeTab.reality.symbol) }
                .tag(ForgeTab.reality)
        }
        .forgeAnimation(ForgeMotion.settle, value: env.tab)
        .sheet(isPresented: $showingCapture) {
            CaptureSheet()
        }
        // §7: saving an idea never lands on a static card; Home turns toward it.
        .onChange(of: env.justCapturedIdeaID) { _, id in
            if id != nil { withAnimation(ForgeMotion.settle) { env.tab = .home } }
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppEnvironment.live)
        .modelContainer(try! .forge(inMemory: true))
}
