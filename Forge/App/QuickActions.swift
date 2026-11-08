import UIKit
import Observation

/// Home Screen quick actions (long-press the app icon). "New idea" opens the
/// capture sheet. The scene delegate hands the item here; the root view takes it.
@Observable
@MainActor
final class QuickActions {
    enum Action: String {
        case newIdea = "app.forge.newIdea"
    }

    static let shared = QuickActions()
    private(set) var pending: Action?

    func receive(_ item: UIApplicationShortcutItem) -> Bool {
        guard let action = Action(rawValue: item.type) else { return false }
        pending = action
        return true
    }

    func take() -> Action? {
        defer { pending = nil }
        return pending
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        config.delegateClass = SceneDelegate.self
        return config
    }
}

final class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem {
            Task { @MainActor in _ = QuickActions.shared.receive(item) }
        }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        Task { @MainActor in completionHandler(QuickActions.shared.receive(shortcutItem)) }
    }
}
