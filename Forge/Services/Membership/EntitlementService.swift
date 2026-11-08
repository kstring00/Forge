import Foundation
import Observation
import ForgeCore

/// Decision 0032: the one place the app asks whether a check may start, and
/// tells what happened. Today `LocalEntitlements` answers from a ledger on the
/// phone. When the proxy ledger (#16) takes over, a `ProxyEntitlements` sends
/// the same calls with the App Store's signed transactions (`jws`) and the
/// proxy decides; nothing that calls this changes.
@MainActor
protocol EntitlementService: AnyObject {
    /// What the App Store says: plan, trial, renewal.
    var state: MembershipState { get }
    /// What can be spent now, for the pill, the confirm sheet and Settings.
    var balance: CheckBalance { get }
    func has(_ feature: PlanFeature) -> Bool
    /// Whether one more check may start while `inFlight` are running.
    func canStartCheck(inFlight: Int) -> Bool
    /// A Brief arrived. Failed and stopped runs never call this.
    func commitCheck(wasFreeOnProxy: Bool)
    /// The App Store's current entitlement, with the signed transactions behind it.
    func apply(_ state: MembershipState, jws: [String])
    /// A top-up was bought. Idempotent per transaction.
    func creditTopUp(transactionID: String, jws: String)
}

/// The ledger on this phone, in UserDefaults. Same rules the proxy will keep.
@Observable
@MainActor
final class LocalEntitlements: EntitlementService {
    static let ledgerKey = "membership.ledger"
    static let stateKey = "membership.state"

    private let defaults: UserDefaults
    private let now: () -> Date
    private(set) var state: MembershipState
    private(set) var ledger: CheckLedger

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.now = now
        state = defaults.data(forKey: Self.stateKey).flatMap { try? JSONDecoder().decode(MembershipState.self, from: $0) } ?? .free
        ledger = defaults.data(forKey: Self.ledgerKey).flatMap { try? JSONDecoder().decode(CheckLedger.self, from: $0) } ?? CheckLedger()
    }

    var balance: CheckBalance { ledger.balance(state, now: now()) }

    func has(_ feature: PlanFeature) -> Bool { state.plan.includes(feature) }

    func canStartCheck(inFlight: Int) -> Bool { ledger.canStart(state, now: now(), inFlight: inFlight) }

    func commitCheck(wasFreeOnProxy: Bool) {
        ledger.commit(state, now: now(), wasFreeOnProxy: wasFreeOnProxy)
        save()
    }

    func apply(_ state: MembershipState, jws: [String]) {
        guard state != self.state else { return }
        self.state = state
        ledger.roll(state, now: now())
        save()
    }

    func creditTopUp(transactionID: String, jws: String) {
        if ledger.creditTopUp(transactionID: transactionID) { save() }
    }

    #if DEBUG
    /// Settings → Developer: monthly checks back, the free first check back. Bought checks stay.
    func resetForTesting() {
        ledger.usedThisPeriod = 0
        ledger.firstFreeUsed = false
        save()
    }
    #endif

    private func save() {
        if let d = try? JSONEncoder().encode(ledger) { defaults.set(d, forKey: Self.ledgerKey) }
        if let d = try? JSONEncoder().encode(state) { defaults.set(d, forKey: Self.stateKey) }
    }
}

extension CheckBalance {
    /// "3 of 15 checks left · resets Dec 1".
    var line: String { line(resets: resetsAt.formatted(.dateTime.month(.abbreviated).day())) }
    /// "resets Dec 1"
    var resetsText: String { "Resets \(resetsAt.formatted(.dateTime.month(.abbreviated).day()))" }
}
