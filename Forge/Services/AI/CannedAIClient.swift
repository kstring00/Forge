import Foundation

/// Returns fixed envelopes per action. For previews and tests of the
/// confirm-before-save flow; never shipped as the live client.
struct CannedAIClient: AIClient {
    var responses: [AIAction: Data] = [:]

    var isAvailable: Bool { true }

    func perform<Payload: Codable & Sendable>(
        _ action: AIAction, context: AIContext, expecting: Payload.Type
    ) async throws -> AIEnvelope<Payload> {
        guard let data = responses[action] else {
            throw AIError.invalidResponse("no canned response for \(action.rawValue)")
        }
        return try JSONDecoder().decode(AIEnvelope<Payload>.self, from: data)
    }

    static func canned<P: Codable & Sendable>(_ payload: P, rationale: String) throws -> Data {
        try JSONEncoder().encode(AIEnvelope(payload: payload, rationale: rationale, model: "canned"))
    }
}
