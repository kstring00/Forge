import Foundation
import Observation

/// Services the views need, injected once at the root.
@Observable
final class AppEnvironment {
    let ai: any AIClient
    let speech: any SpeechCapturing

    init(ai: any AIClient, speech: any SpeechCapturing) {
        self.ai = ai
        self.speech = speech
    }

    static let live = AppEnvironment(ai: OfflineAIClient(), speech: UnavailableSpeechCapture())
}
