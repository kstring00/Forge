import Foundation
import Observation
import ForgeCore

/// Services the views need, injected once at the root.
@Observable
@MainActor
final class AppEnvironment {
    let ai: any AIClient
    let speech: SpeechCapture
    /// Reality Checks run here so they survive navigation and Home can narrate them.
    let realityChecks: RealityCheckCenter
    /// Decision 0041: launch plans, built here so they survive navigation.
    let plans: PlanBuilder
    /// Decision 0032: whether a check may start, and what's left. Local today, the proxy ledger later.
    let entitlements: any EntitlementService
    /// StoreKit 2: products, purchases, restore, renewals.
    let membership: MembershipStore
    /// The Membership screen, from Home's pill, Settings, or the out-of-checks state.
    var showingMembership = false
    /// §7: the idea just saved; Home turns toward it until the user sends it to the panel or taps Later.
    var justCapturedIdeaID: UUID?
    /// The selected tab, here so Home's links and capture can switch it.
    var tab: ForgeTab = .home
    /// The Ideas tab scrolls to this section when set (Home's pipeline nodes), then clears it.
    var ideasSection: Track?
    /// Decision 0028: welcome, the free first check, the guide on the first Brief.
    let firstRun = FirstRun()
    /// The free-check sheet, asked once after the first capture.
    var firstCheckIdeaID: IdeaRef?
    /// The capture sheet, presented once at the root so the dock, Home's mic,
    /// the Home Screen quick action and (next) Siri all open the same sheet.
    var capture: CaptureRequest?

    /// Home → the Ideas tab, scrolled to one section.
    func showIdeas(_ section: Track? = nil) {
        ideasSection = section
        tab = .ideas
    }

    init(ai: any AIClient, speech: SpeechCapture) {
        // Decision 0042: the last plan numbers the proxy sent, before anything counts checks.
        AppEnvironment.loadSavedRules()
        self.ai = ai
        self.speech = speech
        self.realityChecks = RealityCheckCenter(proxy: ai as? ProxyAIClient)
        self.plans = PlanBuilder(proxy: ai as? ProxyAIClient)
        let entitlements = LocalEntitlements(cloud: LedgerCloud())
        self.entitlements = entitlements
        self.membership = MembershipStore(entitlements: entitlements)
        realityChecks.entitlements = entitlements
        plans.entitlements = entitlements
        plans.checks = realityChecks
    }

    static let rulesKey = "planRules"

    static func loadSavedRules(defaults: UserDefaults = .standard) {
        if let d = defaults.data(forKey: rulesKey), let r = try? JSONDecoder().decode(PlanRules.self, from: d) {
            PlanRules.current = r
        }
        applyTestingOverrides(defaults: defaults)
    }

    /// Settings → Developer, test builds: fair-use limits of 1 a day, so the
    /// friendly limit message is easy to reach.
    static let tightFairUseKey = "debug.tightFairUse"

    static func applyTestingOverrides(defaults: UserDefaults = .standard) {
        #if DEBUG
        if defaults.bool(forKey: tightFairUseKey) {
            PlanRules.current.fairUse = .init(launchPlansPerIdeaPerDay: 1, rescoresPerIdeaPerDay: 1, tankRunsPerIdeaPerDay: 1)
        }
        #endif
    }

    /// The rules again from what was saved (or the defaults), then any testing override.
    static func reloadRules(defaults: UserDefaults = .standard) {
        PlanRules.current = PlanRules()
        loadSavedRules(defaults: defaults)
    }

    /// Decision 0042: the plan numbers live in the proxy's config. Fetched at
    /// launch and kept, so they can change without an app update; until the
    /// first answer the built-in defaults (the same numbers) apply.
    func refreshRules(defaults: UserDefaults = .standard) async {
        guard let proxy = ai as? ProxyAIClient, let rules = try? await proxy.health().rules else { return }
        guard rules != PlanRules.current else { return }
        PlanRules.current = rules
        if let d = try? JSONEncoder().encode(rules) { defaults.set(d, forKey: Self.rulesKey) }
        Self.applyTestingOverrides(defaults: defaults)
    }

    /// The proxy client when Local.xcconfig provides a URL and token; otherwise offline.
    static let live = AppEnvironment(ai: ProxyAIClient.configured() ?? OfflineAIClient(), speech: SpeechCapture())
}
