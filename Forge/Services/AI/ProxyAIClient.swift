import Foundation

/// The live client. Talks to the FORGE proxy on Vercel, which holds the key,
/// validates every answer against the contracts and enforces the evidence
/// rules. Configured from Local.xcconfig via Info.plist.
///
/// Proof of origin: a developer token when one is built in (debug builds on
/// a simulator); otherwise App Attest, which signs every request body with a
/// key Apple vouched for, and DeviceCheck where App Attest is unavailable.
/// Release builds carry no token (Base.xcconfig blanks it).
struct ProxyAIClient: AIClient {
    let baseURL: URL
    /// Empty in release builds.
    let token: String
    var session: URLSession = .shared

    var isAvailable: Bool { true }

    /// Nil unless PROXY_URL was set at build time. A token is optional.
    static func configured(bundle: Bundle = .main) -> ProxyAIClient? {
        guard let urlString = bundle.object(forInfoDictionaryKey: "ForgeProxyURL") as? String, !urlString.isEmpty,
              let url = URL(string: urlString) else { return nil }
        let token = (bundle.object(forInfoDictionaryKey: "ForgeProxyToken") as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return ProxyAIClient(baseURL: url, token: token)
    }

    var usesDeveloperToken: Bool { !token.isEmpty }

    @MainActor private static let attest = AppAttest()

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
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let bytes = try encoder.encode(body)
        do {
            return try await send(path: path, bytes: bytes, timeout: timeout)
        } catch AIError.staleAttestation {
            // The proxy's store forgot this key: attest again, once.
            await Self.attest.forget()
            return try await send(path: path, bytes: bytes, timeout: timeout)
        }
    }

    private func send(path: String, bytes: Data, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bytes
        try await addProof(to: &request, body: bytes)

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
        let errorBody = try? JSONDecoder().decode(ErrorBody.self, from: data)
        switch http.statusCode {
        case 200..<300:
            return data
        case 401 where errorBody?.error.code == "attest_unknown_key":
            throw AIError.staleAttestation
        case 401 where (errorBody?.error.code ?? "").hasPrefix("attest_") || (errorBody?.error.code ?? "").hasPrefix("devicecheck_"):
            throw AIError.invalidResponse(errorBody?.error.message ?? "The proxy did not accept this device.")
        case 401, 403, 503:
            throw AIError.notConfigured
        case 429 where errorBody?.error.code == "panel_resting" || errorBody?.error.code == "device_limit":
            throw AIError.resting(errorBody?.error.message ?? "The panel is resting until tomorrow.")
        case 429:
            throw AIError.rateLimited
        case 400, 502:
            throw AIError.invalidResponse(errorBody?.error.message ?? "status \(http.statusCode)")
        case 504:
            // Vercel's own timeout page, not the proxy's JSON.
            throw AIError.invalidResponse("the proxy ran out of time (504). Vercel stopped the function at its limit; check Fluid Compute and maxDuration in vercel.json.")
        default:
            if let message = errorBody?.error.message {
                throw AIError.invalidResponse("status \(http.statusCode): \(message)")
            }
            throw AIError.server(status: http.statusCode)
        }
    }

    /// The developer token when built in; otherwise App Attest or DeviceCheck.
    private func addProof(to request: inout URLRequest, body: Data) async throws {
        if usesDeveloperToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            return
        }
        let proof: AppAttest.Proof
        do {
            proof = try await Self.attest.proof(for: body, attestWith: self)
        } catch let failure as AppAttest.Failure {
            throw AIError.invalidResponse(failure.errorDescription ?? "This device could not be verified.")
        } catch let error as AIError {
            throw error
        } catch {
            throw AIError.invalidResponse("This device could not be verified: \(error.localizedDescription)")
        }
        switch proof {
        case .assertion(let keyId, let assertion):
            request.setValue(keyId, forHTTPHeaderField: "X-Forge-Key-Id")
            request.setValue(assertion, forHTTPHeaderField: "X-Forge-Assertion")
        case .deviceCheck(let deviceToken, let installId):
            request.setValue(deviceToken, forHTTPHeaderField: "X-Forge-Device-Token")
            request.setValue(installId, forHTTPHeaderField: "X-Forge-Install-Id")
        }
    }

    // MARK: Attestation

    private struct ChallengeResponse: Decodable { let challenge: String }
    private struct AttestRequest: Encodable { let keyId: String; let attestation: String; let challenge: String }

    /// A one-time challenge from the proxy. Open: it is how a device earns access.
    func attestChallenge() async throws -> String {
        let data = try await plainPost(path: "api/attest", bytes: Data("{}".utf8), timeout: 20)
        return try JSONDecoder().decode(ChallengeResponse.self, from: data).challenge
    }

    func registerAttestation(keyId: String, attestation: String, challenge: String) async throws {
        let bytes = try JSONEncoder().encode(AttestRequest(keyId: keyId, attestation: attestation, challenge: challenge))
        _ = try await plainPost(path: "api/attest", bytes: bytes, timeout: 30)
    }

    /// A POST with no proof attached, for the attestation route only.
    private func plainPost(path: String, bytes: Data, timeout: TimeInterval) async throws -> Data {
        var request = URLRequest(url: baseURL.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = timeout
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bytes
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw AIError.offline
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.invalidResponse("no HTTP response") }
        guard (200..<300).contains(http.statusCode) else {
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error.message ?? "status \(http.statusCode)"
            throw AIError.invalidResponse(message)
        }
        return data
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
        if usesDeveloperToken { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw AIError.server(status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return try JSONDecoder().decode(Health.self, from: data)
    }
}
