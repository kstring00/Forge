import SwiftUI

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var env
    @State private var tab: ForgeTab = .home
    @State private var showingCapture = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tab) {
                HomeView(onCapture: { showingCapture = true })
                    .tabItem { Label(ForgeTab.home.title, systemImage: ForgeTab.home.symbol) }
                    .badge(env.realityChecks.unseenBriefs.isEmpty ? 0 : env.realityChecks.unseenBriefs.count)
                    .tag(ForgeTab.home)
                VaultView()
                    .tabItem { Label(ForgeTab.vault.title, systemImage: ForgeTab.vault.symbol) }
                    .tag(ForgeTab.vault)
                WorkshopView()
                    .tabItem { Label(ForgeTab.workshop.title, systemImage: ForgeTab.workshop.symbol) }
                    .tag(ForgeTab.workshop)
            }

            // Home has its own capture field; the Vault gets the floating button, hidden while scrolling down.
            if tab == .vault && !env.vaultScrollHidesFAB {
                EmberButton.floating(title: "Capture", symbol: "plus") {
                    showingCapture = true
                }
                .padding(.trailing, ForgeSpacing.l)
                .padding(.bottom, ForgeSpacing.xxl + ForgeSpacing.l)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .forgeAnimation(ForgeMotion.settle, value: tab)
        .forgeAnimation(ForgeMotion.fade, value: env.vaultScrollHidesFAB)
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
