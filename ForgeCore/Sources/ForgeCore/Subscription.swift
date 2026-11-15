import Foundation

/// Decision 0043: what StoreKit 2 says about one subscription, in plain
/// values. The app fills it from `Transaction.currentEntitlements` and the
/// subscription's status (`Product.SubscriptionInfo.Status`); everything that
/// decides the plan from it lives here, where it is tested.
public struct SubscriptionSnapshot: Equatable, Sendable {
    /// Apple's `Product.SubscriptionInfo.RenewalState`.
    public enum Renewal: String, Equatable, Sendable { case subscribed, inGracePeriod, inBillingRetry, expired, revoked }

    /// The product the person has now (`currentProductID`), not the one booked next.
    public var productID: String
    public var transactionID: String
    /// When the current billing period began: an upgrade, a switch at renewal
    /// and every renewal are new transactions with their own purchase date.
    public var purchaseDate: Date
    public var expiresAt: Date?
    public var isTrial: Bool
    /// In `Transaction.currentEntitlements`: subscribed or in the grace period.
    public var isEntitled: Bool
    public var renewal: Renewal
    public var willAutoRenew: Bool
    /// `RenewalInfo.autoRenewPreference`: what it renews to.
    public var autoRenewProductID: String?
    public var gracePeriodEndsAt: Date?
    public var familyShared: Bool
    /// The reference name of the offer code this billing period was bought
    /// with, as set in App Store Connect (StoreKit's `offer.id` when the offer
    /// type is `code`). Nil without an offer code.
    public var offerCodeID: String?

    public init(productID: String, transactionID: String, purchaseDate: Date, expiresAt: Date?, isTrial: Bool = false,
                isEntitled: Bool = true, renewal: Renewal = .subscribed, willAutoRenew: Bool = true,
                autoRenewProductID: String? = nil, gracePeriodEndsAt: Date? = nil, familyShared: Bool = false, offerCodeID: String? = nil) {
        self.productID = productID
        self.transactionID = transactionID
        self.purchaseDate = purchaseDate
        self.expiresAt = expiresAt
        self.isTrial = isTrial
        self.isEntitled = isEntitled
        self.renewal = renewal
        self.willAutoRenew = willAutoRenew
        self.autoRenewProductID = autoRenewProductID
        self.gracePeriodEndsAt = gracePeriodEndsAt
        self.familyShared = familyShared
        self.offerCodeID = offerCodeID
    }

    /// The one that decides the plan when there are several (the person's own
    /// and a family-shared one): entitled first, then the higher plan, then
    /// the newer billing period.
    public static func deciding(_ all: [SubscriptionSnapshot]) -> SubscriptionSnapshot? {
        all.filter { MembershipProduct.plan(for: $0.productID) != nil }.max { a, b in
            if a.isEntitled != b.isEntitled { return !a.isEntitled }
            let pa = MembershipProduct.plan(for: a.productID)!, pb = MembershipProduct.plan(for: b.productID)!
            if pa != pb { return pa < pb }
            return a.purchaseDate < b.purchaseDate
        }
    }
}

extension MembershipState {
    /// The one source of truth for the plan: Apple's current entitlement and
    /// its renewal info. Nothing entitled is Free; a failed renewal past the
    /// grace period is Free with a billing note, until the payment goes through.
    public init(entitlement s: SubscriptionSnapshot?, rules: PlanRules = .current) {
        guard let s, let plan = MembershipProduct.plan(for: s.productID) else { self = .free; return }
        guard s.isEntitled else {
            self = .free
            if s.renewal == .inBillingRetry { billing = .retrying(productID: s.productID) }
            return
        }
        let billing: BillingStatus = switch s.renewal {
        case .inGracePeriod: .gracePeriod(until: s.gracePeriodEndsAt)
        // Still entitled while Apple retries the payment: the plan is on, with a payment problem to fix.
        case .inBillingRetry: .gracePeriod(until: s.gracePeriodEndsAt)
        default: .ok
        }
        let next = s.willAutoRenew ? s.autoRenewProductID.flatMap { $0 == s.productID ? nil : $0 } : nil
        self.init(plan: plan, isTrial: s.isTrial, anchor: s.purchaseDate, productID: s.productID, renewsAt: s.expiresAt,
                  founding: s.productID == MembershipProduct.plusYearly && s.offerCodeID != nil && s.offerCodeID == rules.foundingOfferID,
                  transactionID: s.transactionID,
                  willAutoRenew: s.willAutoRenew, nextProductID: next, billing: billing, familyShared: s.familyShared)
    }

    /// One plain line under "You're on …" on the plan screen and in Settings.
    /// `date` formats a date the way the app shows it ("Dec 9").
    public func statusLine(date: (Date) -> String) -> String {
        let ends = renewsAt.map(date) ?? "the end of this period"
        switch billing {
        case .gracePeriod:
            return "Your last payment didn't go through. \(plan.displayName) stays on while Apple tries again. Update your payment details to keep it."
        case .retrying(let id):
            let name = id.flatMap(MembershipProduct.plan(for:))?.displayName ?? "Your plan"
            return "Your last payment didn't go through, so \(name) is paused. Update your payment details to get it back."
        case .ok:
            break
        }
        guard plan != .free else { return "Free: \(Plan.free.monthlyChecks) check a month." }
        if isCancelled { return "\(plan.displayName) ends \(ends). You'll move to Free." }
        if let next = nextProductID {
            let nextName = MembershipProduct.displayName(next)
            return nextPlan == plan
                ? "You're on \(MembershipProduct.displayName(productID ?? "")) until \(ends), then \(nextName)."
                : "You're on \(plan.displayName) until \(ends), then \(nextName)."
        }
        if isTrial { return "Free trial until \(ends), then \(MembershipProduct.displayName(productID ?? ""))." }
        return "\(plan.displayName) renews \(ends)."
    }
}

extension MembershipProduct {
    /// "Plus · monthly", "Plus · yearly", "Pro · yearly".
    public static func displayName(_ id: String) -> String {
        switch id {
        case plusMonthly: "Plus · monthly"
        case plusYearly: "Plus · yearly"
        case proMonthly: "Pro · monthly"
        case proYearly: "Pro · yearly"
        default: plan(for: id)?.displayName ?? "Free"
        }
    }
}

/// What picking a product does for this person, by Apple's rules (decision
/// 0043): an upgrade starts now and Apple credits the unused part of the old
/// plan; a downgrade, or the same plan for a different length, starts at the
/// next renewal and costs nothing until then. (Apple starts a switch between
/// two products on the same level with the same length at once, but Hunch has
/// no such pair: each level has one monthly and one yearly product. The
/// founding price is an offer code on Plus yearly, not a product.)
public enum PlanOption: Equatable, Sendable {
    /// Nothing active (or Free): buying starts it today.
    case subscribe
    /// The product the person has, renewing as it is.
    case current
    /// The product the person has, cancelled: it ends on this date.
    case currentEnding(Date?)
    /// The product the person has, with a switch booked: tapping keeps it.
    case currentSwitching(to: String, on: Date?)
    /// Already booked for the next renewal.
    case booked(Date?)
    case upgradeNow
    case switchesOn(Date?)

    public static func `for`(_ productID: String, in state: MembershipState) -> PlanOption {
        guard state.plan != .free, let current = state.productID,
              let have = MembershipProduct.level(current), let want = MembershipProduct.level(productID) else { return .subscribe }
        if productID == current {
            if state.isCancelled { return .currentEnding(state.renewsAt) }
            if let next = state.nextProductID { return .currentSwitching(to: next, on: state.renewsAt) }
            return .current
        }
        if productID == state.nextProductID { return .booked(state.renewsAt) }
        if want < have { return .upgradeNow }
        // A downgrade, or the same plan for a different length: at renewal.
        return .switchesOn(state.renewsAt)
    }

    /// The label on the card: "Current", "Upgrade now", "Switches on Dec 9".
    public func badge(date: (Date) -> String) -> String? {
        func on(_ d: Date?) -> String { d.map(date) ?? "your renewal date" }
        switch self {
        case .subscribe: return nil
        case .current, .currentSwitching: return "Current"
        case .currentEnding(let d): return "Ends \(on(d))"
        case .booked(let d): return "Starts \(on(d))"
        case .upgradeNow: return "Upgrade now"
        case .switchesOn(let d): return "Switches on \(on(d))"
        }
    }

    /// What happens, said plainly before the person confirms. Nil when there
    /// is nothing to confirm. `price` is the App Store's price for the
    /// product, with its period ("$9.99 a month").
    public func confirmation(productID: String, in state: MembershipState, price: String, date: (Date) -> String) -> String? {
        let newName = MembershipProduct.displayName(productID)
        let oldName = state.productID.map(MembershipProduct.displayName) ?? state.plan.displayName
        func on(_ d: Date?) -> String { d.map(date) ?? "your renewal date" }
        switch self {
        case .subscribe:
            return "\(newName) starts today at \(price)."
        case .current, .booked:
            return nil
        case .currentEnding(let d):
            return "\(oldName) carries on instead of ending on \(on(d)). Nothing is charged today; the next payment is on \(on(d)) at \(price)."
        case .currentSwitching(let next, let d):
            return "You stay on \(oldName). The switch to \(MembershipProduct.displayName(next)) on \(on(d)) is cancelled. Nothing is charged today."
        case .upgradeNow:
            return "\(newName) starts now. Apple charges \(price) today and gives back the unused part of \(oldName). Your checks for the month start fresh, and up to \(state.plan.monthlyChecks) unused and carried-over ones come with you."
        case .switchesOn(let d):
            return "You keep \(oldName) until \(on(d)). \(newName) starts then at \(price). Nothing is charged today."
        }
    }
}
