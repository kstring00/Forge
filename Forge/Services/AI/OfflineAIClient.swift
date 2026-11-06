import Foundation

/// Phase 0 stand-in. Every action reports offline so screens can show their
/// calm "offline" state. Replaced by the proxy client in Phase 2.
public struct OfflineAIClient: AIClient {
    public init() {}
    public var isAvailable: Bool { false }

    public func perform<Payload: Codable & Sendable>(
        _ action: AIAction, context: AIContext, expecting: Payload.Type
    ) async throws -> AIEnvelope<Payload> {
        throw AIError.offline
    }
}
