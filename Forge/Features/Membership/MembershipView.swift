import SwiftUI
import StoreKit
import ForgeCore

/// Decision 0032, the "Membership · Free / Plus / Pro" artboard. Reached from
/// Home's checks pill, Settings, and the out-of-checks state; never on launch,
/// during capture, or after a failed run. Carries the required subscription
/// disclosures, Restore, and Manage.
struct MembershipView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    /// Opens on Monthly: the smaller number first (decision 0039).
    @State private var period: MembershipStore.Period = .monthly
    @State private var managing = false
    @State private var showingPrivacy = false
    @State private var redeeming = false
    /// A plan change waiting for the person to confirm it.
    @State private var change: Change?

    private var store: MembershipStore { env.membership }
    private var state: MembershipState { env.entitlements.state }
    private var balance: CheckBalance { env.entitlements.balance }
    private var plusYearlyID: String { MembershipProduct.plusYearly }
    private var plusID: String { period == .monthly ? MembershipProduct.plusMonthly : MembershipProduct.plusYearly }
    private var proID: String { period == .monthly ? MembershipProduct.proMonthly : MembershipProduct.proYearly }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                hero
                statusLine
                periodToggle
                planCard(.free)
                planCard(.plus)
                planCard(.pro)
                topUpRow
                legal
            }
            .padding(.horizontal, 20)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(alignment: .top) {
            SkyHeader().frame(height: 300).ignoresSafeArea()
        }
        .background(ForgeColor.canvas)
        .overlay(alignment: .bottom) { banner }
        .manageSubscriptionsSheet(isPresented: $managing)
        // Decision 0043: founders redeem their offer code here (Plus yearly, first year at the founding price).
        .offerCodeRedemption(isPresented: $redeeming) { _ in Task { await store.refresh() } }
        .sheet(isPresented: $showingPrivacy) { PrivacySummarySheet() }
        .alert(change?.title ?? "", isPresented: Binding(get: { change != nil }, set: { if !$0 { change = nil } }), presenting: change) { c in
            Button(c.confirm) { Task { await perform(c) } }
            Button("Not now", role: .cancel) {}
        } message: { c in
            Text(c.message)
        }
        .task {
            await store.load()
            await store.refresh()
        }
    }

    // MARK: Top

    private var hero: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                        .frame(width: 44, height: 44).background(.black.opacity(0.25), in: Circle())
                }
                .accessibilityLabel("Close")
                Spacer()
                Button("Restore") { Task { await store.restore() } }
                    .font(.system(.subheadline, weight: .medium)).foregroundStyle(.white).underline()
                    .accessibilityLabel("Restore purchases")
            }
            .padding(.top, ForgeSpacing.m)
            Text("Choose your plan")
                .font(Font.custom("Fraunces-SemiBold", size: 34, relativeTo: .largeTitle))
                .foregroundStyle(ForgeColor.ink)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                .padding(.top, ForgeSpacing.l)
            Text("A check is one idea researched by the panel. Everything you do yourself is free.")
                .font(.subheadline).foregroundStyle(ForgeColor.ink.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.3), radius: 6, y: 1)
        }
    }

    /// Your plan, what happens next, and what's left. The breakdown lives in Settings.
    private var statusLine: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(statusLabel).forgeLabelSmall()
            if state.plan != .free || state.billing.hasIssue {
                Text(state.statusLine(date: day))
                    .font(.subheadline).foregroundStyle(heads ? ForgeColor.emberText : ForgeColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(balance.pillLine).font(.subheadline.weight(.semibold)).foregroundStyle(ForgeColor.ink)
                .fixedSize(horizontal: false, vertical: true)
            if state.billing.hasIssue {
                Button("Update payment details") { openURL(BillingIssueBanner.billingURL) }
                    .font(.subheadline.weight(.semibold)).foregroundStyle(ForgeColor.emberText)
            }
        }
        .padding(ForgeSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(heads ? ForgeColor.ember.opacity(0.6) : ForgeColor.line))
        .accessibilityElement(children: .combine)
    }

    /// Something is about to change: a booked switch, a cancel, a payment problem.
    private var heads: Bool { state.nextProductID != nil || state.isCancelled || state.billing.hasIssue }

    private var statusLabel: String {
        var s = "You're on \(state.plan.displayName)"
        if state.isTrial { s += " · free trial" }
        if state.founding { s += " · founding member" }
        return s
    }

    private var periodToggle: some View {
        HStack(spacing: 4) {
            ForEach(MembershipStore.Period.allCases, id: \.self) { p in
                let on = period == p
                Button { withAnimation(ForgeMotion.settle) { period = p } } label: {
                    Text(p == .monthly ? "Monthly" : "Yearly · save \(store.saving(monthly: MembershipProduct.plusMonthly, yearly: plusYearlyID))%")
                        .font(.system(.subheadline, weight: .medium))
                        .foregroundStyle(on ? ForgeColor.canvas : ForgeColor.inkSecondary)
                        .frame(maxWidth: .infinity).frame(height: 40)
                        .background(on ? ForgeColor.ink : Color.clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(on ? .isSelected : [])
            }
        }
        .padding(4)
        .background(ForgeColor.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(ForgeColor.line))
    }

    // MARK: Plans

    /// One card per plan: name, price, one line, and what tapping does, by
    /// Apple's rules (decision 0043): Current, Upgrade now, or Switches on a date.
    private func planCard(_ plan: Plan) -> some View {
        let id = productID(plan)
        let option = id.map { PlanOption.for($0, in: state) }
        let mine = state.plan == plan
        return VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(plan.displayName).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                if let badge = badge(plan, option) {
                    Text(badge).font(.caption.weight(.semibold)).foregroundStyle(ForgeColor.canvas)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(mine ? ForgeColor.ink : ForgeColor.ember, in: Capsule())
                }
                Spacer()
                Text(priceLine(plan)).font(.system(.headline)).foregroundStyle(ForgeColor.ink)
            }
            Text(what(plan)).font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let note = note(plan, option) {
                Text(note).font(.footnote).foregroundStyle(ForgeColor.emberText).fixedSize(horizontal: false, vertical: true)
            }
            if let id, let option {
                action(plan, id: id, option: option)
            } else if plan == .free, state.plan != .free, !state.isCancelled {
                manageLink
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous)
            .strokeBorder(mine ? ForgeColor.ink.opacity(0.6) : ForgeColor.line, lineWidth: mine ? 1.5 : 1))
    }

    private func productID(_ plan: Plan) -> String? {
        switch plan {
        case .free: nil
        case .plus: plusID
        case .pro: proID
        }
    }

    private func priceLine(_ plan: Plan) -> String {
        guard let id = productID(plan) else { return "Free" }
        return "\(store.price(id)) / \(MembershipProduct.isYearly(id) ? "year" : "month")"
    }

    /// "$9.99 a month", for what people are told before they confirm.
    private func priceWithPeriod(_ id: String) -> String {
        "\(store.price(id)) a \(MembershipProduct.isYearly(id) ? "year" : "month")"
    }

    private func what(_ plan: Plan) -> String {
        switch plan {
        case .free:
            "\(Plan.free.monthlyChecks) \(Plan.free.monthlyChecks == 1 ? "check" : "checks") a month. Launch plans and re-scores on checked ideas are included."
        case .plus:
            "\(Plan.plus.monthlyChecks) checks a month, and unused ones carry over. Shows where your instincts are right."
        case .pro:
            "\(Plan.pro.monthlyChecks) checks a month, faster answers and deeper research."
        }
    }

    private func badge(_ plan: Plan, _ option: PlanOption?) -> String? {
        guard let option else {
            // Free: where a cancelled plan lands.
            if state.plan == .free { return "Current" }
            return state.isCancelled ? "From \(renewalDay)" : nil
        }
        return option.badge(date: day)
    }

    /// One short line only when it matters: a trial, a booked switch, going back to Free.
    private func note(_ plan: Plan, _ option: PlanOption?) -> String? {
        switch option {
        case .subscribe where plan == .plus:
            if period == .yearly && store.trialEligible { return "7 days free, up to \(MembershipState.trialChecks) checks. Cancel anytime." }
            return nil
        case .booked(let d):
            return "Starts \(d.map(day) ?? "at your renewal"). Nothing is charged until then."
        case nil where plan == .free && state.plan != .free && !state.isCancelled:
            return "To go back to Free, cancel in Manage subscription. Your plan runs until \(renewalDay)."
        default:
            return nil
        }
    }

    @ViewBuilder
    private func action(_ plan: Plan, id: String, option: PlanOption) -> some View {
        switch option {
        case .current:
            manageLink
        case .booked:
            EmptyView()
        case .currentSwitching:
            HStack(spacing: ForgeSpacing.l) {
                Button("Keep \(plan.displayName)") { ask(id, option) }
                manageLink
            }
            .font(.subheadline.weight(.semibold)).foregroundStyle(ForgeColor.emberText)
        case .currentEnding:
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                bigButton("Resubscribe", id: id, emphasised: true) { ask(id, option) }
                manageLink
            }
        case .subscribe:
            bigButton(subscribeTitle(plan), id: id, emphasised: plan == .plus) { Task { await store.purchase(id) } }
        case .upgradeNow:
            bigButton("Upgrade now", id: id, emphasised: true) { ask(id, option) }
        case .switchesOn(let d):
            bigButton("Switch on \(d.map(day) ?? "renewal")", id: id, emphasised: false) { ask(id, option) }
        }
    }

    private var manageLink: some View {
        Button("Manage subscription") { managing = true }
            .font(.subheadline.weight(.medium)).foregroundStyle(ForgeColor.emberText)
    }

    private func bigButton(_ title: String, id: String, emphasised: Bool, _ tap: @escaping () -> Void) -> some View {
        Button(action: tap) {
            Group {
                if store.purchasing == id { ProgressView().tint(emphasised ? .white : ForgeColor.ink) } else { Text(title) }
            }
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(emphasised ? .white : ForgeColor.ink)
            .frame(maxWidth: .infinity).frame(minHeight: 48)
            .background(emphasised ? ForgeColor.ember : ForgeColor.canvas, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(emphasised ? Color.clear : ForgeColor.line))
        }
        .buttonStyle(.plain)
        .disabled(store.purchasing != nil)
    }

    private func subscribeTitle(_ plan: Plan) -> String {
        if plan == .plus && period == .yearly && store.trialEligible { return "Try Plus free for 7 days" }
        return "Choose \(plan.displayName)"
    }

    // MARK: Confirming a change

    private struct Change {
        let productID: String
        let option: PlanOption
        let title: String
        let confirm: String
        let message: String
    }

    /// Says plainly what happens before anything is bought or booked.
    private func ask(_ id: String, _ option: PlanOption) {
        let name = MembershipProduct.displayName(id)
        let current = state.plan.displayName
        let (title, confirm): (String, String) = switch option {
        case .upgradeNow: ("Upgrade to \(name)?", "Upgrade now")
        case .switchesOn(let d): ("Switch to \(name) on \(d.map(day) ?? "renewal")?", "Book the switch")
        case .currentSwitching: ("Keep \(current)?", "Keep \(current)")
        case .currentEnding: ("Keep \(current)?", "Resubscribe")
        default: ("", "")
        }
        guard let message = option.confirmation(productID: id, in: state, price: priceWithPeriod(id), date: day) else { return }
        change = Change(productID: id, option: option, title: title, confirm: confirm, message: message)
    }

    private func perform(_ c: Change) async {
        switch c.option {
        case .currentSwitching, .currentEnding:
            // Apple's Manage sheet always works when re-buying doesn't.
            if await store.keepCurrent() == .failed { managing = true }
        default:
            await store.purchase(c.productID)
        }
    }

    /// "Dec 9".
    private func day(_ date: Date) -> String { date.formatted(.dateTime.month(.abbreviated).day()) }

    /// "Dec 9", or "your renewal" before the App Store has said.
    private var renewalDay: String { state.renewsAt.map(day) ?? "your renewal" }

    private var topUpRow: some View {
        HStack {
            Text("Need a few more? \(MembershipProduct.topUpChecks) extra checks, never expire.")
                .font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 8)
            Button { Task { await store.purchase(MembershipProduct.topUp5) } } label: {
                Group {
                    if store.purchasing == MembershipProduct.topUp5 { ProgressView() } else { Text(store.price(MembershipProduct.topUp5)) }
                }
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                .padding(.horizontal, 16).frame(height: 40)
                .background(ForgeColor.canvas, in: Capsule())
                .overlay(Capsule().strokeBorder(ForgeColor.line))
            }
            .buttonStyle(.plain)
            .disabled(store.purchasing != nil)
            .accessibilityLabel("Buy \(MembershipProduct.topUpChecks) extra checks for \(store.price(MembershipProduct.topUp5))")
        }
        .padding(.horizontal, 4)
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Subscriptions renew automatically unless cancelled at least 24 hours before the period ends. Payment is charged to your Apple ID; manage or cancel in your Apple account settings. A check that fails doesn't count.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: ForgeSpacing.l) {
                Button("Redeem a code") { redeeming = true }
                Button("Terms") { openURL(LegalLinks.terms) }
                Button("Privacy") {
                    if let url = LegalLinks.privacy { openURL(url) } else { showingPrivacy = true }
                }
            }
            .font(.system(.footnote, weight: .medium)).foregroundStyle(ForgeColor.emberText).underline()
        }
        .padding(.top, ForgeSpacing.s)
    }

    @ViewBuilder
    private var banner: some View {
        if let message = store.message {
            HStack(alignment: .top, spacing: ForgeSpacing.s) {
                Text(message).font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                Spacer()
                Button { store.dismissMessage() } label: { Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary) }
                    .accessibilityLabel("Dismiss")
            }
            .padding(ForgeSpacing.m)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.6)))
            .padding(ForgeSpacing.m)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
}

/// Terms is Apple's standard licence agreement until Hunch has its own. The
/// privacy policy URL arrives with TestFlight item 4; until then the link
/// opens what is and isn't sent.
enum LegalLinks {
    static let terms = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacy: URL? = nil
}

struct PrivacySummarySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("What is sent, only when you ask for a check") { ForEach(AIConsent.whatIsSent, id: \.self) { Text($0) } }
                Section("Never sent") { ForEach(AIConsent.neverSent, id: \.self) { Text($0) } }
                Section { Text("Everything else stays on this phone. Nothing is sold. The full privacy policy is published before the app ships.") }
            }
            .navigationTitle("Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

/// The checks pill on Home: "3 of 15 checks left · resets Dec 1". Opens Membership.
struct ChecksPill: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Button { env.showingMembership = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "circle.hexagonpath").font(.system(.footnote, weight: .semibold))
                Text(env.entitlements.balance.pillLine).font(.system(.footnote, weight: .medium)).lineLimit(2).fixedSize(horizontal: false, vertical: true)
                Image(systemName: "chevron.right").font(.system(.footnote, weight: .bold)).opacity(0.7)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12).padding(.vertical, 6).frame(minHeight: 32)
            .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(env.entitlements.balance.pillLine). Opens plans and checks.")
    }
}

/// Decision 0043: a renewal payment failed. Friendly, never the paywall; the
/// plan stays on through Apple's grace period. Shown on Home under the pill.
struct BillingIssueBanner: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.openURL) private var openURL
    /// Apple's page for updating the payment method on this Apple ID.
    static let billingURL = URL(string: "https://apps.apple.com/account/billing")!

    var body: some View {
        let state = env.entitlements.state
        if state.billing.hasIssue {
            Button { openURL(Self.billingURL) } label: {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "creditcard").font(.system(.footnote, weight: .semibold))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.statusLine(date: { $0.formatted(.dateTime.month(.abbreviated).day()) }))
                            .font(.footnote).fixedSize(horizontal: false, vertical: true)
                        Text("Update payment details").font(.footnote.weight(.semibold)).underline()
                    }
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ForgeColor.ember.opacity(0.85), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }
}
