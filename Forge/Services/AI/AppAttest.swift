import Foundation
import CryptoKit
import DeviceCheck
import Security

/// How a release build proves it is a genuine, unmodified copy of Hunch
/// before the proxy spends anything. No shared secret ships in the binary.
///
/// App Attest: once per install, a key is made in the Secure Enclave and
/// Apple vouches for it to the proxy (`/api/attest`). On every call the key
/// signs the request body; the proxy checks the signature and a counter that
/// only moves forward. If App Attest is not available on the device, the
/// fallback is a DeviceCheck token with a per-install id.
///
/// Debug builds that carry a developer token in Local.xcconfig skip all of
/// this and use the token; release builds have no token.
@MainActor
final class AppAttest {
    enum Proof {
        case assertion(keyId: String, assertion: String)
        case deviceCheck(token: String, installId: String)
    }

    enum Failure: LocalizedError {
        case unsupported
        case attestationRejected(String)

        var errorDescription: String? {
            switch self {
            case .unsupported: "This device can't prove it's running a genuine copy of the app, so the panel can't be reached."
            case .attestationRejected(let m): "The proxy did not accept this device: \(m)"
            }
        }
    }

    private let service = DCAppAttestService.shared
    private let keychain = KeychainBox(service: "app.hunch.attest")
    private var attestedKeyId: String? {
        didSet { if let attestedKeyId { keychain.set(attestedKeyId, for: "attestedKeyId") } else { keychain.remove("attestedKeyId") } }
    }

    init() {
        attestedKeyId = keychain.get("attestedKeyId")
    }

    var isSupported: Bool { service.isSupported }

    /// A proof for one request: the body's SHA-256 signed by the attested key,
    /// attesting first if this install has not yet.
    func proof(for body: Data, attestWith proxy: ProxyAIClient) async throws -> Proof {
        if service.isSupported {
            let keyId = try await ensureAttested(with: proxy)
            let hash = Data(SHA256.hash(data: body))
            let assertion = try await service.generateAssertion(keyId, clientDataHash: hash)
            return .assertion(keyId: keyId, assertion: assertion.base64EncodedString())
        }
        guard DCDevice.current.isSupported else { throw Failure.unsupported }
        let token = try await DCDevice.current.generateToken()
        return .deviceCheck(token: token.base64EncodedString(), installId: installId)
    }

    /// The proxy no longer knows this key (its store was reset): attest again on the next call.
    func forget() {
        attestedKeyId = nil
        keychain.remove("keyId")
    }

    private func ensureAttested(with proxy: ProxyAIClient) async throws -> String {
        if let attestedKeyId { return attestedKeyId }
        let keyId: String
        if let saved = keychain.get("keyId") {
            keyId = saved
        } else {
            keyId = try await service.generateKey()
            keychain.set(keyId, for: "keyId")
        }
        let challenge = try await proxy.attestChallenge()
        let clientDataHash = Data(SHA256.hash(data: Data(challenge.utf8)))
        let attestation: Data
        do {
            attestation = try await service.attestKey(keyId, clientDataHash: clientDataHash)
        } catch {
            // A key Apple will no longer attest (for example after a restore) is replaced.
            keychain.remove("keyId")
            throw error
        }
        do {
            try await proxy.registerAttestation(keyId: keyId, attestation: attestation.base64EncodedString(), challenge: challenge)
        } catch let AIError.invalidResponse(message) {
            throw Failure.attestationRejected(message)
        }
        attestedKeyId = keyId
        return keyId
    }

    /// A per-install id for the DeviceCheck door. Random, kept in the keychain.
    private var installId: String {
        if let id = keychain.get("installId") { return id }
        let id = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        keychain.set(id, for: "installId")
        return id
    }
}

/// The smallest keychain wrapper that holds a few strings for this app.
struct KeychainBox {
    let service: String

    func get(_ key: String) -> String? {
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                    kSecAttrAccount as String: key, kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func set(_ value: String, for key: String) {
        remove(key)
        let add: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
                                  kSecAttrAccount as String: key, kSecValueData as String: Data(value.utf8),
                                  kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]
        SecItemAdd(add as CFDictionary, nil)
    }

    func remove(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service, kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}
