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

    static let live = AppEnvironment(ai: OfflineAIClient(), speech: SpeechCapture())
}
