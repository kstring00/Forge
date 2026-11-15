import SwiftUI
import SwiftData

@main
struct ForgeApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    private let container: ModelContainer
    private let environment = AppEnvironment.live
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .dark

    init() {
        NavigationBarStyle.apply()
        // Dark by default (§8), before the first window exists.
        let stored = Appearance(rawValue: UserDefaults.standard.string(forKey: Appearance.storageKey) ?? "") ?? .dark
        UIWindow.appearance().overrideUserInterfaceStyle = stored.interfaceStyle
        do {
            container = try ModelContainer.forge()
        } catch {
            // A broken store on a personal device is better surfaced than hidden.
            fatalError("FORGE could not open its data store: \(error)")
        }
        // Records written before a rule existed: ids out of prose, targets from the step text.
        LegacyCleanup.runIfNeeded(in: container.mainContext)
        // Decision 0025: one project per idea. Duplicates merge into the newest, orphans are archived; the report sits in Settings.
        ProjectCleanup.runIfNeeded(in: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(environment)
                .tint(ForgeColor.ember)
                .preferredColorScheme(appearance.colorScheme)
                // Belt and braces: sheets and UIKit chrome follow the window's style too.
                .onAppear { Appearance.applyToWindows(appearance) }
                .onChange(of: appearance) { _, a in Appearance.applyToWindows(a) }
        }
        .modelContainer(container)
    }
}
