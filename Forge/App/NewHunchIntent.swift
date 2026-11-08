import AppIntents

/// Decision 0026: "Hey Siri, new hunch", a Shortcuts action, and the Action
/// button all open the app straight into voice capture. Nothing is recorded
/// until the sheet is up and the mic is live; nothing is sent anywhere.
struct NewHunchIntent: AppIntent {
    static let title: LocalizedStringResource = "New hunch"
    static let description = IntentDescription("Opens the app ready to hear your idea.")
    static let openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        QuickActions.shared.request(.newHunch)
        return .result()
    }
}

/// The phrases Siri listens for. Each must name the app; the name comes from
/// the bundle's display name, so it follows the rename to Hunch.
struct HunchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewHunchIntent(),
            phrases: [
                "New hunch in \(.applicationName)",
                "\(.applicationName) new hunch",
                "Catch a hunch in \(.applicationName)",
                "Capture an idea in \(.applicationName)",
            ],
            shortTitle: "New hunch",
            systemImageName: "mic.fill"
        )
    }
}
