import Foundation

/// The live client. Talks to the FORGE proxy on Vercel, which holds the key,
/// validates every answer against the contracts and enforces the evidence
/// rules. Configured from Local.xcconfig via Info.plist; absent that, the app
/// stays on the offline client.
struct ProxyAIClient: AIClient {
    let baseURL: URL
    let token: String
    var session: URLSession = .shared

    var isAvailable: Bool { true }

    /// Nil unless both PROXY_URL and PROXY_TOKEN were set at build time.
    static func configured(bundle: Bundle = .main) -> ProxyAIClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "ForgeProxyURL") as? String, !urlString.isEmpty,
              let token = bundle.object(forInfoDictionaryKey: "ForgeProxyToken") as? String, !token.isEmpty,
              let url = URL(string: urlString) else { return nil }
        return ProxyAIClient(baseURL: url, token: token)
    }

    private struct ActionRequest<C: Encodable>: Encodable {
        let action: String
        let context: C
        let options: [String: String]?
    }

    private struct ErrorBody: Decodable {
        struct Inner: Decodable { let code: String; let message: String }
        let error: Inner
    }

    func perform<Payload: Codable & Sendable>(
        _ action: AIAction, context: AIContext, expecting: Payload.Type
    ) async throws -> AIEnvelope<Payload> {
        try await perform(action, context: context, options: nil, expecting: expecting)
    }

    func perform<Payload: Codable & Sendable>(
        _ action: AIAction, context: AIContext, options: [String: String]?, expecting: Payload.Type
    ) async throws -> AIEnvelope<Payload> {
        let body = ActionRequest(action: action.rawValue, context: context, options: options)
        // The proxy allows an action up to 300 s (vercel.json); a prefill can take minutes.
        let data = try await post(path: "api/action", body: body, timeout: 290)
        do {
            return try JSONDecoder().decode(AIEnvelope<Payload>.self, from: data)
        } catch {
            throw AIError.invalidResponse(String(describing: error))
        }
    }

    // MARK: Transport

    func post<B: Encodable>(path: String, body: B, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        request.httpBody = try encoder.encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost, .timedOut, .dnsLookupFailed:
                throw AIError.offline
            default:
                throw AIError.server(status: urlError.errorCode)
            }
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse("no HTTP response") }
        switch http.statusCode {
        case 200..<300:
            return data
        case 401, 403, 503:
            throw AIError.notConfigured
        case 429:
            throw AIError.rateLimited
        case 400, 502:
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message ?? "status \(http.statusCode)"
            throw AIError.invalidResponse(message)
        default:
            throw AIError.server(status: http.statusCode)
        }
    }

    // MARK: Health

    struct Health: Decodable {
        struct Estimate: Decodable { let realityCheckUSD: Range }
        struct Range: Decodable { let low: Double; let high: Double }
        let ok: Bool
        let version: String
        let authorized: Bool
        let estimate: Estimate
    }

    func health() async throws -> Health {
        var request = URLRequest(url: baseURL.appending(path: "api/health"))
        request.timeoutInterval = 15
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(Health.self, from: data)
    }
}
