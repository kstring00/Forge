import SwiftUI

struct RootTabView: View {
    @State private var tab: ForgeTab = .home
    @State private var showingCapture = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $tab) {
                HomeView(onCapture: { showingCapture = true })
                    .tabItem { Label(ForgeTab.home.title, systemImage: ForgeTab.home.symbol) }
                    .tag(ForgeTab.home)
                VaultView()
                    .tabItem { Label(ForgeTab.vault.title, systemImage: ForgeTab.vault.symbol) }
                    .tag(ForgeTab.vault)
                WorkshopView()
                    .tabItem { Label(ForgeTab.workshop.title, systemImage: ForgeTab.workshop.symbol) }
                    .tag(ForgeTab.workshop)
            }

            // Home has its own Quick Capture card; the Vault gets the floating button.
            if tab == .vault {
                EmberButton.floating(title: "Capture", symbol: "plus") {
                    showingCapture = true
                }
                .padding(.trailing, ForgeSpacing.l)
                .padding(.bottom, ForgeSpacing.xxl + ForgeSpacing.l)
                .transition(.scale(scale: 0.9).combined(with: .opacity))
            }
        }
        .forgeAnimation(ForgeMotion.settle, value: tab)
        .sheet(isPresented: $showingCapture) {
            CaptureSheet()
        }
    }
}

#Preview {
    RootTabView()
        .environment(AppEnvironment.live)
        .modelContainer(try! .forge(inMemory: true))
}
