import UIKit
import Observation

/// Ways in from outside the app: the Home Screen quick action "New idea"
/// (long-press the icon) and the "New hunch" App Intent (Siri, Shortcuts, the
/// Action button). Each lands here; the root view takes it and opens capture.
@Observable
@MainActor
final class QuickActions {
    enum Action: String {
        /// Long-press the icon: the capture sheet, keyboard up.
        case newIdea = "app.forge.newIdea"
        /// Siri, Shortcuts, the Action button: the capture sheet, already listening.
        case newHunch = "app.forge.newHunch"
    }

    static let shared = QuickActions()
    private(set) var pending: Action?

    func request(_ action: Action) { pending = action }

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
