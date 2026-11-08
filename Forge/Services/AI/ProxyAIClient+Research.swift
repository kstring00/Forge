import Foundation

/// Desk research through the proxy: one web search + fetch turn per call.
/// Loop while `status` is paused, passing `messages` back unchanged.
struct ResearchResponse: Decodable {
    struct Source: Decodable {
        let url: String
        let title: String
        let text: String
        let kind: String          // "fetched" | "searchHit"
        let retrievedAt: String?
    }
    let status: String            // "done" | "paused"
    /// Decision 0027: true on the opening turn of this device's free first check. Absent from older proxies.
    let freeCheck: Bool?
    let messages: [JSONValue]
    let sources: [Source]
    let notes: String
    let model: String
    let costUSD: Double
}

extension ProxyAIClient {
    private struct ResearchRequest: Encodable {
        struct IdeaRef: Encodable { let id: UUID; let title: String; let originalText: String }
        let idea: IdeaRef
        let advantages: [String]
        let constraints: [String]
        let messages: [JSONValue]?
    }

    func research(ideaID: UUID, title: String, originalText: String,
                  advantages: [String], constraints: [String], messages: [JSONValue]?) async throws -> ResearchResponse {
        let body = ResearchRequest(idea: .init(id: ideaID, title: title, originalText: originalText),
                                   advantages: advantages, constraints: constraints, messages: messages)
        let data = try await post(path: "api/research", body: body, timeout: 125, withDeviceToken: messages == nil)
        do {
            return try JSONDecoder().decode(ResearchResponse.self, from: data)
        } catch {
            throw AIError.invalidResponse(String(describing: error))
        }
    }
}
