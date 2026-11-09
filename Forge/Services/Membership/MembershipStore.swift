import Foundation
import Observation
import StoreKit
import ForgeCore

/// Decision 0032: StoreKit 2. Loads the products, buys, restores, listens for
/// renewals and refunds, and hands what the App Store says to the
/// `EntitlementService`. In the simulator it runs against Hunch.storekit.
@Observable
@MainActor
final class MembershipStore {
    enum Period: String, CaseIterable { case monthly, yearly }

    private(set) var products: [String: Product] = [:]
    private(set) var loading = false
    private(set) var purchasing: String?
    private(set) var message: String?
    private(set) var trialEligible = true
    private let entitlements: any EntitlementService
    private var updates: Task<Void, Never>?
    private var statusUpdates: Task<Void, Never>?

    init(entitlements: any EntitlementService) {
        self.entitlements = entitlements
    }

    /// Founding members (TestFlight testers) see Plus yearly at the founding price.
    /// The proxy will flag testers by account later; for now a TestFlight build or Debug.
    var showsFoundingOffer: Bool {
        #if DEBUG
        return UserDefaults.standard.object(forKey: "membership.foundingPreview") as? Bool ?? true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    // MARK: Lifecycle

    /// Once at launch: listen first (so nothing is missed), then unfinished
    /// transactions, products, and what the App Store says now.
    func start() async {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
            }
        }
        // Renewal info changes (a downgrade booked in Apple's sheet or in
        // Settings, a cancel, a billing problem) aren't transactions.
        statusUpdates = Task { [weak self] in
            for await _ in Product.SubscriptionInfo.Status.updates {
                await self?.refresh()
            }
        }
        for await result in Transaction.unfinished { await handle(result) }
        await load()
        await refresh()
    }

    func load() async {
        guard products.isEmpty, !loading else { return }
        loading = true
        defer { loading = false }
        do {
            let list = try await Product.products(for: MembershipProduct.all)
            products = Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
            if let yearly = products[MembershipProduct.plusYearly], let sub = yearly.subscription {
                trialEligible = await sub.isEligibleForIntroOffer
            }
        } catch {
            message = "The App Store didn't answer. Prices shown are the usual ones."
        }
    }

    /// Decision 0043: the one source of truth for the plan. The entitled
    /// transaction (`Transaction.currentEntitlements`: subscribed or in the
    /// grace period) plus its renewal info (`Product.SubscriptionInfo.Status`):
    /// what it renews to, whether it will, billing trouble. Never the latest
    /// transaction alone: after a downgrade Apple still has the person on Pro
    /// until renewal, with Plus only in the renewal info.
    func refresh() async {
        var entitled: [UInt64: Transaction] = [:]
        var jws: [String] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil, !t.isUpgraded,
                  t.productType == .autoRenewable, MembershipProduct.plan(for: t.productID) != nil else { continue }
            jws.append(result.jwsRepresentation)
            entitled[t.originalID] = t
        }
        var snapshots: [SubscriptionSnapshot] = []
        var described = Set<UInt64>()
        for status in await statuses() {
            guard case .verified(let latest) = status.transaction else { continue }
            let info: Product.SubscriptionInfo.RenewalInfo?
            if case .verified(let r) = status.renewalInfo { info = r } else { info = nil }
            let t = entitled[latest.originalID] ?? latest
            snapshots.append(Self.snapshot(t, state: status.state, info: info, entitled: entitled[latest.originalID] != nil))
            described.insert(latest.originalID)
        }
        // Entitled but with no status (the status call failed): still the plan.
        for (id, t) in entitled where !described.contains(id) {
            snapshots.append(Self.snapshot(t, state: .subscribed, info: nil, entitled: true))
        }
        entitlements.apply(MembershipState(entitlement: SubscriptionSnapshot.deciding(snapshots)), jws: jws)
    }

    private func statuses() async -> [Product.SubscriptionInfo.Status] {
        if products.isEmpty { await load() }
        guard let product = MembershipProduct.subscriptions.lazy.compactMap({ self.products[$0] }).first,
              let subscription = product.subscription else { return [] }
        return (try? await subscription.status) ?? []
    }

    private static func snapshot(_ t: Transaction, state: Product.SubscriptionInfo.RenewalState,
                                 info: Product.SubscriptionInfo.RenewalInfo?, entitled: Bool) -> SubscriptionSnapshot {
        let renewal: SubscriptionSnapshot.Renewal =
            state == .subscribed ? .subscribed
            : state == .inGracePeriod ? .inGracePeriod
            : state == .inBillingRetryPeriod ? .inBillingRetry
            : state == .revoked ? .revoked
            : .expired
        return SubscriptionSnapshot(productID: t.productID, transactionID: String(t.id), purchaseDate: t.purchaseDate,
                                    expiresAt: t.expirationDate, isTrial: isIntroductory(t), isEntitled: entitled,
                                    renewal: renewal, willAutoRenew: info?.willAutoRenew ?? true,
                                    autoRenewProductID: info?.autoRenewPreference, gracePeriodEndsAt: info?.gracePeriodExpirationDate,
                                    familyShared: t.ownershipType == .familyShared)
    }

    // MARK: Buying

    enum Outcome { case done, pending, cancelled, failed }

    /// Buys, or changes plan. Apple decides when a change starts: an upgrade
    /// now, a downgrade or a monthly ↔ yearly switch at renewal (no new
    /// transaction until then; the refresh reads the booking).
    @discardableResult
    func purchase(_ productID: String) async -> Outcome {
        guard let product = products[productID] else {
            message = "That plan isn't available right now. Try again in a moment."
            return .failed
        }
        purchasing = productID
        message = nil
        defer { purchasing = nil }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await handle(result)
                return .done
            case .pending:
                message = "Waiting for approval. Your plan starts as soon as it's approved."
                return .pending
            case .userCancelled:
                return .cancelled
            @unknown default:
                return .cancelled
            }
        } catch {
            message = "The purchase didn't go through: \(error.localizedDescription)"
            return .failed
        }
    }

    /// Keep the current plan: undo a booked switch, or turn renewal back on
    /// after a cancel. Re-buying the current product does it in Xcode and the
    /// sandbox; the App Store has been seen to refuse it, so on failure the
    /// caller opens Apple's Manage sheet (`.failed`), where it always works.
    func keepCurrent() async -> Outcome {
        guard let id = entitlements.state.productID else { return .failed }
        let outcome = await purchase(id)
        await refresh()
        guard outcome == .done else {
            if outcome == .failed { message = nil }
            return outcome
        }
        let kept = entitlements.state.nextProductID == nil && entitlements.state.willAutoRenew
        return kept ? .done : .failed
    }

    /// Restore purchases: asks the App Store to resend this Apple ID's
    /// transactions, then rebuilds the plan and cycle dates from them. Bought
    /// top-ups in the history are remembered but not given again: how many
    /// were spent lives in the ledger (and its iCloud copy), not at Apple.
    func restore() async {
        message = nil
        do {
            try await AppStore.sync()
            var known: [String] = []
            for await result in Transaction.all {
                guard case .verified(let t) = result, t.productID == MembershipProduct.topUp5 else { continue }
                if t.revocationDate != nil { entitlements.refundTopUp(transactionID: String(t.id)) }
                else { known.append(String(t.id)) }
            }
            entitlements.recordKnownTopUps(known)
            await refresh()
            message = entitlements.state.plan == .free ? "Nothing to restore on this Apple ID." : "Restored: \(entitlements.state.plan.displayName)."
        } catch {
            message = "Couldn't reach the App Store to restore. Try again in a moment."
        }
    }

    func dismissMessage() { message = nil }

    /// Grants what a transaction bought (or takes back a refunded top-up),
    /// finishes it, then re-reads the plan. A top-up is credited once per
    /// transaction ID, however often it is delivered.
    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else {
            message = "The App Store couldn't verify that purchase, so nothing changed."
            return
        }
        if t.productID == MembershipProduct.topUp5 {
            if t.revocationDate != nil {
                entitlements.refundTopUp(transactionID: String(t.id))
            } else {
                entitlements.creditTopUp(transactionID: String(t.id), jws: result.jwsRepresentation)
            }
        }
        await t.finish()
        await refresh()
    }

    private static func isIntroductory(_ t: Transaction) -> Bool {
        if #available(iOS 17.2, *) { return t.offer?.type == .introductory }
        return t.offerType == .introductory
    }

    // MARK: Prices

    func price(_ id: String) -> String {
        products[id]?.displayPrice ?? MembershipProduct.fallbackPrice(id).formatted(.currency(code: "USD"))
    }

    /// "$5.00 a month" for a yearly product.
    func perMonth(_ id: String) -> String {
        if let p = products[id] { return (p.price / 12).formatted(p.priceFormatStyle) }
        return (MembershipProduct.fallbackPrice(id) / 12).formatted(.currency(code: "USD"))
    }

    func saving(monthly: String, yearly: String) -> Int {
        MembershipProduct.yearlySaving(monthly: products[monthly]?.price ?? MembershipProduct.fallbackPrice(monthly),
                                       yearly: products[yearly]?.price ?? MembershipProduct.fallbackPrice(yearly))
    }
}
