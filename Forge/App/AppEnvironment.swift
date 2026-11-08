import Foundation
import Observation

/// Services the views need, injected once at the root.
@Observable
@MainActor
final class AppEnvironment {
    let ai: any AIClient
    let speech: SpeechCapture
    /// Reality Checks run here so they survive navigation and Home can narrate them.
    let realityChecks: RealityCheckCenter
    /// §7: the idea just saved; Home turns toward it until the user sends it to the panel or taps Later.
    var justCapturedIdeaID: UUID?
    /// The selected tab, here so Home's links and capture can switch it.
    var tab: ForgeTab = .home
    /// The Ideas tab scrolls to this section when set (Home's pipeline nodes), then clears it.
    var ideasSection: Track?
    /// The capture sheet, presented once at the root so the dock, Home's mic,
    /// the Home Screen quick action and (next) Siri all open the same sheet.
    var capture: CaptureRequest?

    /// Home → the Ideas tab, scrolled to one section.
    func showIdeas(_ section: Track? = nil) {
        ideasSection = section
        tab = .ideas
    }

    init(ai: any AIClient, speech: SpeechCapture) {
        self.ai = ai
        self.speech = speech
        self.realityChecks = RealityCheckCenter(proxy: ai as? ProxyAIClient)
    }

    /// The proxy client when Local.xcconfig provides a URL and token; otherwise offline.
    static let live = AppEnvironment(ai: ProxyAIClient.configured() ?? OfflineAIClient(), speech: SpeechCapture())
}
