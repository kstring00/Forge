import Foundation
import Observation
import ForgeCore

/// Decision 0028: the first run. Welcome, the free first check, the one-time
/// guide on the first Brief. Flags live in UserDefaults; a Debug replay shows
/// every screen again without touching them or spending the real free check.
@Observable
@MainActor
final class FirstRun {
    enum GuideStep: String, CaseIterable { case verdict, orbs, nextStep }

    static let welcomeKey = "firstRun.welcomeSeen"
    static let guideKey = "firstRun.guideDismissedSteps"

    private let defaults: UserDefaults
    private(set) var welcomeSeen: Bool
    private(set) var dismissedSteps: Set<GuideStep>
    /// Debug: the flow runs again on top of real state and leaves it alone.
    private(set) var replaying = false
    private var replayDismissed: Set<GuideStep> = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        welcomeSeen = defaults.bool(forKey: Self.welcomeKey)
        dismissedSteps = Set((defaults.stringArray(forKey: Self.guideKey) ?? []).compactMap(GuideStep.init(rawValue:)))
    }

    // MARK: Welcome

    /// The welcome shows once, before anything exists; and again on replay.
    func showsWelcome(ideasEmpty: Bool) -> Bool { replaying || (!welcomeSeen && ideasEmpty) }

    func markWelcomeSeen() {
        guard !replaying else { return }
        welcomeSeen = true
        defaults.set(true, forKey: Self.welcomeKey)
    }

    // MARK: The free check

    /// Offered after a capture while this phone has never had a check come
    /// back. The proxy is the judge of free; this only decides whether to ask.
    func offersFirstCheck(hasAnyCheck: Bool) -> Bool { replaying || !hasAnyCheck }

    // MARK: The guide on the first Brief

    func showsGuide(_ step: GuideStep) -> Bool {
        replaying ? !replayDismissed.contains(step) : !dismissedSteps.contains(step)
    }

    var guideDismissed: Bool { dismissedSteps.count == GuideStep.allCases.count }

    /// Dismissed callouts never come back. The replay ends with its last one.
    func dismiss(_ step: GuideStep) {
        if replaying {
            replayDismissed.insert(step)
            if replayDismissed.count == GuideStep.allCases.count { endReplay() }
            return
        }
        dismissedSteps.insert(step)
        defaults.set(dismissedSteps.map(\.rawValue).sorted(), forKey: Self.guideKey)
    }

    // MARK: Replay (Debug)

    func startReplay() {
        replayDismissed = []
        replaying = true
    }

    func endReplay() {
        replaying = false
        replayDismissed = []
    }
}

/// The bundled example, behind "No idea right now? See an example" on the
/// welcome screen and nowhere else. Long enough for the guard, names a
/// problem and a person, and is a Business idea the desk can research.
enum ExampleIdea {
    static let title = "Weekend site care for RV parks"
    static let text = "A weekend website-care service for RV parks along one highway corridor. Most park owners run a Facebook page and a phone number, lose bookings to parks with a real site, and don't have anyone to call when it breaks. One simple page, a booking link, and a monthly check-in visit for a flat fee."
}
