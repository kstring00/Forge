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
    /// Decision 0041: whether `checks` can be spent at once (a launch plan), with `inFlight` checks running.
    func canSpend(_ checks: Int, inFlight: Int) -> Bool
    /// A plan arrived: spend its checks. Failed runs never call this.
    func spend(_ checks: Int)
    /// Decision 0042: whether an included follow-up on this idea is under today's fair-use limit.
    func canUse(_ followUp: FollowUp, ideaID: UUID) -> Bool
    /// An included follow-up arrived. Failed runs never call this.
    func recordUse(_ followUp: FollowUp, ideaID: UUID)
    /// The App Store's current entitlement, with the signed transactions behind it.
    func apply(_ state: MembershipState, jws: [String])
    /// A top-up was bought. Idempotent per transaction.
    func creditTopUp(transactionID: String, jws: String)
    /// A top-up was refunded: its unused checks go. Idempotent per transaction.
    func refundTopUp(transactionID: String)
    /// Top-ups found in the App Store's history on Restore: remembered, never credited twice.
    func recordKnownTopUps(_ transactionIDs: [String])
}

/// The ledger on this phone, in UserDefaults. Same rules the proxy will keep.
@Observable
@MainActor
final class LocalEntitlements: EntitlementService {
    static let ledgerKey = "membership.ledger"
    static let stateKey = "membership.state"
    static let fairUseKey = "membership.fairUse"

    private let defaults: UserDefaults
    private let now: () -> Date
    private let cloud: LedgerCloud?
    private(set) var state: MembershipState
    private(set) var ledger: CheckLedger
    private(set) var fairUse: FairUseLedger

    init(defaults: UserDefaults = .standard, now: @escaping () -> Date = Date.init, cloud: LedgerCloud? = nil) {
        self.defaults = defaults
        self.now = now
        self.cloud = cloud
        state = defaults.data(forKey: Self.stateKey).flatMap { try? JSONDecoder().decode(MembershipState.self, from: $0) } ?? .free
        ledger = defaults.data(forKey: Self.ledgerKey).flatMap { try? JSONDecoder().decode(CheckLedger.self, from: $0) } ?? CheckLedger()
        fairUse = defaults.data(forKey: Self.fairUseKey).flatMap { try? JSONDecoder().decode(FairUseLedger.self, from: $0) } ?? FairUseLedger()
        // Decision 0043: after a reinstall or on a new phone, iCloud's copy brings
        // back carried-over and bought checks, and the used free first check.
        if let remote = cloud?.read() { ledger = ledger.merged(with: remote) }
        // Decision 0042: record the cycle we're in at launch, so a cycle with no
        // checks still carries its unused ones into the next.
        ledger.roll(state, now: now())
        save()
        cloud?.onChange = { [weak self] remote in self?.mergeFromCloud(remote) }
    }

    private func mergeFromCloud(_ remote: CheckLedger) {
        let merged = ledger.merged(with: remote)
        guard merged != ledger else { return }
        ledger = merged
        save()
    }

    var balance: CheckBalance { ledger.balance(state, now: now()) }

    func has(_ feature: PlanFeature) -> Bool { state.plan.includes(feature) }

    func canStartCheck(inFlight: Int) -> Bool { ledger.canStart(state, now: now(), inFlight: inFlight) }

    func commitCheck(wasFreeOnProxy: Bool) {
        ledger.commit(state, now: now(), wasFreeOnProxy: wasFreeOnProxy)
        save()
    }

    func canSpend(_ checks: Int, inFlight: Int) -> Bool { ledger.canSpend(checks, state, now: now(), inFlight: inFlight) }

    func spend(_ checks: Int) {
        guard checks > 0 else { return }
        ledger.spend(checks, state, now: now())
        save()
    }

    func canUse(_ followUp: FollowUp, ideaID: UUID) -> Bool { fairUse.canUse(followUp, ideaID: ideaID, now: now()) }

    func recordUse(_ followUp: FollowUp, ideaID: UUID) {
        fairUse.record(followUp, ideaID: ideaID, now: now())
        if let d = try? JSONEncoder().encode(fairUse) { defaults.set(d, forKey: Self.fairUseKey) }
    }

    func apply(_ state: MembershipState, jws: [String]) {
        guard state != self.state else { return }
        self.state = state
        ledger.roll(state, now: now())
        save()
    }

    func creditTopUp(transactionID: String, jws: String) {
        if ledger.creditTopUp(transactionID: transactionID, now: now(), plan: state.plan) { save() }
    }

    func refundTopUp(transactionID: String) {
        ledger.refundTopUp(transactionID: transactionID, now: now(), plan: state.plan)
        save()
    }

    func recordKnownTopUps(_ transactionIDs: [String]) {
        if ledger.recordKnownTopUps(transactionIDs) > 0 { save() }
    }

    #if DEBUG
    /// Settings → Developer: pretend this cycle ended, so the next one starts now
    /// and this cycle's unused checks carry over (decision 0042, F).
    func startNextCycleForTesting() {
        let cal = Calendar.current
        ledger.periodStart = cal.date(byAdding: .month, value: -1, to: ledger.periodStart) ?? ledger.periodStart
        if let end = ledger.periodEnd { ledger.periodEnd = cal.date(byAdding: .month, value: -1, to: end) }
        ledger.roll(state, now: now())
        save()
    }

    /// Settings → Developer: monthly checks back, the free first check back. Bought checks stay.
    /// (With iCloud on, another device's copy can mark the free check used again.)
    func resetForTesting() {
        ledger.usedThisPeriod = 0
        ledger.firstFreeUsed = false
        save()
    }
    #endif

    private func save() {
        if let d = try? JSONEncoder().encode(ledger) { defaults.set(d, forKey: Self.ledgerKey) }
        if let d = try? JSONEncoder().encode(state) { defaults.set(d, forKey: Self.stateKey) }
        cloud?.write(ledger)
    }
}

extension CheckBalance {
    /// "3 of 15 checks left · resets Dec 1".
    var line: String { line(resets: resetsAt.formatted(.dateTime.month(.abbreviated).day())) }
    /// "resets Dec 1"
    var resetsText: String { "Resets \(resetsAt.formatted(.dateTime.month(.abbreviated).day()))" }
    /// "19 checks left · 4 carried over expire Dec 3"
    var pillLine: String { pillLine(resets: resetsAt.formatted(.dateTime.month(.abbreviated).day())) }
    var expiresText: String { resetsAt.formatted(.dateTime.month(.abbreviated).day()) }
}
