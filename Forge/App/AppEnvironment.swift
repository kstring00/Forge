import Foundation
import Observation

/// Services the views need, injected once at the root.
@Observable
@MainActor
final class AppEnvironment {
    let ai: any AIClient
    let speech: SpeechCapture

    init(ai: any AIClient, speech: SpeechCapture) {
        self.ai = ai
        self.speech = speech
    }

    /// The proxy client when Local.xcconfig provides a URL and token; otherwise offline.
    static let live = AppEnvironment(ai: ProxyAIClient.configured() ?? OfflineAIClient(), speech: SpeechCapture())
}
