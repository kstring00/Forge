import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    private let container: ModelContainer
    private let environment = AppEnvironment.live
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark

    init() {
        do {
            container = try ModelContainer.forge()
        } catch {
            // A broken store on a personal device is better surfaced than hidden.
            fatalError("FORGE could not open its data store: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(environment)
                .tint(ForgeColor.ember)
                .preferredColorScheme(appearance.colorScheme)
        }
        .modelContainer(container)
    }
}
