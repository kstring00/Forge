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

    /// Once at launch: products, current entitlements, unfinished transactions, then listen.
    func start() async {
        guard updates == nil else { return }
        updates = Task { [weak self] in
            for await result in Transaction.updates {
                await self?.handle(result)
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

    /// The highest active subscription in the group decides the plan.
    func refresh() async {
        var best: (Plan, Transaction)?
        var jws: [String] = []
        for await result in Transaction.currentEntitlements {
            guard case .verified(let t) = result, t.revocationDate == nil,
                  let plan = MembershipProduct.plan(for: t.productID) else { continue }
            jws.append(result.jwsRepresentation)
            if best == nil || plan > best!.0 { best = (plan, t) }
        }
        guard let (plan, t) = best else {
            entitlements.apply(.free, jws: [])
            return
        }
        entitlements.apply(MembershipState(plan: plan, isTrial: Self.isIntroductory(t), anchor: t.originalPurchaseDate,
                                           productID: t.productID, renewsAt: t.expirationDate,
                                           founding: t.productID == MembershipProduct.plusFoundingYearly), jws: jws)
    }

    // MARK: Buying

    func purchase(_ productID: String) async {
        guard let product = products[productID] else {
            message = "That plan isn't available right now. Try again in a moment."
            return
        }
        purchasing = productID
        message = nil
        defer { purchasing = nil }
        do {
            switch try await product.purchase() {
            case .success(let result):
                await handle(result)
            case .pending:
                message = "Waiting for approval. Your plan starts as soon as it's approved."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            message = "The purchase didn't go through: \(error.localizedDescription)"
        }
    }

    /// Restore purchases: asks the App Store to resend this Apple ID's transactions.
    func restore() async {
        message = nil
        do {
            try await AppStore.sync()
            await refresh()
            message = entitlements.state.plan == .free ? "Nothing to restore on this Apple ID." : "Restored: \(entitlements.state.plan.displayName)."
        } catch {
            message = "Couldn't reach the App Store to restore. Try again in a moment."
        }
    }

    func dismissMessage() { message = nil }

    private func handle(_ result: VerificationResult<Transaction>) async {
        guard case .verified(let t) = result else {
            message = "The App Store couldn't verify that purchase, so nothing changed."
            return
        }
        if t.productType == .consumable, t.productID == MembershipProduct.topUp5, t.revocationDate == nil {
            entitlements.creditTopUp(transactionID: String(t.id), jws: result.jwsRepresentation)
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
