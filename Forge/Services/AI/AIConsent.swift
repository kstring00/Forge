import Foundation

/// Brief §12: the app tells the user once, before the first AI call, that idea
/// text and sources are sent to an AI provider through the user's own proxy,
/// and asks for consent. Settings shows what is sent and lets them withdraw.
enum AIConsent {
    static let storageKey = "ai.consentGrantedAt"   // TimeInterval since 1970; 0 or missing = not granted
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static var grantedAt: Date? {
        let t = defaults.double(forKey: storageKey)
        return t > 0 ? Date(timeIntervalSince1970: t) : nil
    }

    static var isGranted: Bool { grantedAt != nil }

    static func grant(at date: Date = .now) {
        defaults.set(date.timeIntervalSince1970, forKey: storageKey)
    }

    static func withdraw() {
        defaults.removeObject(forKey: storageKey)
    }

    static let whatIsSent: [String] = [
        "The idea's title and original text",
        "Your answers to the Explore prompts and your notes on the idea",
        "The kind of idea, and the scores and evidence you have recorded",
        "Sources you have saved to the idea",
        "The project's outcome, next step and Journal entries, when you ask about a project"
    ]

    static let neverSent: [String] = [
        "Voice recordings",
        "Ideas other than the one you tapped the action on",
        "Your Steward charter, except to the Steward",
        "Anything from outside Hunch"
    ]

    /// The proxy the app is built with, from Local.xcconfig via Info.plist. Nil until Phase 3.
    static var proxyURL: String? {
        let v = Bundle.main.object(forInfoDictionaryKey: "ForgeProxyURL") as? String
        return (v?.isEmpty ?? true) ? nil : v
    }
}
