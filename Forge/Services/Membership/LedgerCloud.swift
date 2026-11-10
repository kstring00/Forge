import Foundation
import ForgeCore

/// Decision 0043: a copy of the check ledger in the person's iCloud
/// key-value store, so carried-over and bought checks survive deleting the
/// app and follow their Apple ID to a new phone, until the server ledger
/// (#22) takes over. Copies merge without ever adding checks
/// (`CheckLedger.merged(with:)`), and the free first check stays used.
///
/// Works only when the app is signed with the iCloud key-value entitlement
/// (Forge/Config/Forge.entitlements, switched on in Local.xcconfig once a
/// development team is set). Without it, reads come back empty and writes
/// stay on this phone: the same as before.
@MainActor
final class LedgerCloud {
    static let key = "membership.ledger.v1"

    /// The iCloud copy, only when this build is set up for it (the entitlement
    /// and `HUNCH_LEDGER_IN_ICLOUD = YES`, both in Local.xcconfig). Asking for
    /// the key-value store without the entitlement is an error in Apple's eyes.
    static func ifEnabled() -> LedgerCloud? {
        (Bundle.main.object(forInfoDictionaryKey: "HunchLedgerInICloud") as? String) == "YES" ? LedgerCloud() : nil
    }
    private let store: NSUbiquitousKeyValueStore
    private var observer: NSObjectProtocol?
    /// Called with iCloud's copy when another device (or a restore) changed it.
    var onChange: ((CheckLedger) -> Void)?

    init(store: NSUbiquitousKeyValueStore = .default) {
        self.store = store
        observer = NotificationCenter.default.addObserver(forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                                                          object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let remote = self.read() else { return }
                self.onChange?(remote)
            }
        }
        store.synchronize()
    }

    func read() -> CheckLedger? {
        store.data(forKey: Self.key).flatMap { try? JSONDecoder().decode(CheckLedger.self, from: $0) }
    }

    func write(_ ledger: CheckLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        store.set(data, forKey: Self.key)
    }
}
