import SwiftUI

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var tab: ForgeTab = .home
    @State private var showingCapture = false

    var body: some View {
        TabView(selection: $tab) {
            HomeView(onCapture: { showingCapture = true })
                .tabItem { Label(ForgeTab.home.title, systemImage: ForgeTab.home.symbol) }
                .badge(env.realityChecks.unseenBriefs.isEmpty ? 0 : env.realityChecks.unseenBriefs.count)
                .tag(ForgeTab.home)
            // Home has its own capture field; the Vault list carries the floating
            // button itself, so it never follows the user into an idea.
            VaultView(onCapture: { showingCapture = true })
                .tabItem { Label(ForgeTab.vault.title, systemImage: ForgeTab.vault.symbol) }
                .tag(ForgeTab.vault)
            WorkshopView()
                .tabItem { Label(ForgeTab.workshop.title, systemImage: ForgeTab.workshop.symbol) }
                .tag(ForgeTab.workshop)
        }
        .forgeAnimation(ForgeMotion.settle, value: tab)
        .sheet(isPresented: $showingCapture) {
            CaptureSheet()
        }
        // §7: saving an idea never lands on a static card; Home turns the orbs toward it.
        .onChange(of: env.justCapturedIdeaID) { _, id in
            if id != nil { withAnimation(ForgeMotion.settle) { tab = .home } }
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppEnvironment.live)
        .modelContainer(try! .forge(inMemory: true))
}
