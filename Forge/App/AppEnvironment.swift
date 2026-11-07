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
    /// §7: the idea just saved; Home turns the orbs toward it until the user runs a check or taps Later.
    var justCapturedIdeaID: UUID?

    init(ai: any AIClient, speech: SpeechCapture) {
        self.ai = ai
        self.speech = speech
        self.realityChecks = RealityCheckCenter(proxy: ai as? ProxyAIClient)
    }

    /// The proxy client when Local.xcconfig provides a URL and token; otherwise offline.
    static let live = AppEnvironment(ai: ProxyAIClient.configured() ?? OfflineAIClient(), speech: SpeechCapture())
}
