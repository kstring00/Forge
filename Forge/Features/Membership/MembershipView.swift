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

    private var store: MembershipStore { env.membership }
    private var state: MembershipState { env.entitlements.state }
    private var balance: CheckBalance { env.entitlements.balance }
    private var founding: Bool { period == .yearly && store.showsFoundingOffer }
    /// The one yearly Plus this person is offered: founding for testers, regular otherwise.
    /// Both tabs quote it, so Monthly and Yearly never disagree.
    private var plusYearlyID: String { store.showsFoundingOffer ? MembershipProduct.plusFoundingYearly : MembershipProduct.plusYearly }
    private var plusID: String {
        period == .monthly ? MembershipProduct.plusMonthly : (founding ? MembershipProduct.plusFoundingYearly : MembershipProduct.plusYearly)
    }
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
        .sheet(isPresented: $showingPrivacy) { PrivacySummarySheet() }
        .task { await store.load() }
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

    /// One line: your plan and what's left. The breakdown lives in Settings.
    private var statusLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(statusLabel).forgeLabelSmall()
            Text(balance.pillLine).font(.subheadline.weight(.semibold)).foregroundStyle(ForgeColor.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(ForgeSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .accessibilityElement(children: .combine)
    }

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

    /// One card per plan: name, price, one line, one button. Your plan says so.
    private func planCard(_ plan: Plan) -> some View {
        let current = state.plan == plan
        return VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(alignment: .firstTextBaseline) {
                Text(plan.displayName).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                if current {
                    Text("Your plan").font(.caption.weight(.semibold)).foregroundStyle(ForgeColor.canvas)
                        .padding(.horizontal, 8).padding(.vertical, 3)
                        .background(ForgeColor.ink, in: Capsule())
                }
                Spacer()
                Text(priceLine(plan)).font(.system(.headline)).foregroundStyle(ForgeColor.ink)
            }
            Text(what(plan)).font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let note = note(plan) {
                Text(note).font(.footnote).foregroundStyle(ForgeColor.emberText).fixedSize(horizontal: false, vertical: true)
            }
            action(plan, current: current)
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous)
            .strokeBorder(current ? ForgeColor.ink.opacity(0.6) : ForgeColor.line, lineWidth: current ? 1.5 : 1))
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
        return "\(store.price(id)) / \(period == .yearly ? "year" : "month")"
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

    /// One short line only when it matters: a trial, a founding price, a switch that waits for renewal.
    private func note(_ plan: Plan) -> String? {
        switch plan {
        case .plus:
            if state.plan == .pro { return "You keep Pro until \(renewalDay), then Plus starts. You're never charged twice." }
            if founding && state.plan == .free { return "Founding member price, kept as long as you stay subscribed." }
            if period == .yearly && store.trialEligible && state.plan == .free { return "7 days free, up to \(MembershipState.trialChecks) checks. Cancel anytime." }
            return nil
        case .free:
            return state.plan != .free ? "To go back to Free, cancel in Manage subscription. Your paid plan runs until \(renewalDay)." : nil
        case .pro:
            return nil
        }
    }

    @ViewBuilder
    private func action(_ plan: Plan, current: Bool) -> some View {
        if current {
            if plan != .free {
                HStack(spacing: ForgeSpacing.l) {
                    // Same plan, other billing period: offer the switch.
                    if let id = productID(plan), state.productID != id {
                        Button(store.purchasing == id ? "Switching…" : "Switch to \(period == .yearly ? "yearly" : "monthly")") {
                            Task { await store.purchase(id) }
                        }
                        .disabled(store.purchasing != nil)
                    }
                    Button("Manage subscription") { managing = true }
                }
                .font(.subheadline.weight(.medium)).foregroundStyle(ForgeColor.emberText)
            }
        } else if plan == .free {
            if state.plan != .free {
                Button("Manage subscription") { managing = true }
                    .font(.subheadline.weight(.medium)).foregroundStyle(ForgeColor.emberText)
            }
        } else if let id = productID(plan) {
            // The one orange button is the plan most people should pick next.
            let emphasised = (plan == .plus && state.plan == .free) || (plan == .pro && state.plan == .plus)
            Button { Task { await store.purchase(id) } } label: {
                Group {
                    if store.purchasing == id { ProgressView().tint(emphasised ? .white : ForgeColor.ink) } else { Text(buttonTitle(plan)) }
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
    }

    private func buttonTitle(_ plan: Plan) -> String {
        switch plan {
        case .plus:
            if state.plan == .pro { return "Switch to Plus on \(renewalDay)" }
            if founding { return "Join as a founding member" }
            if period == .yearly && store.trialEligible && state.plan == .free { return "Try Plus free for 7 days" }
            return "Choose Plus"
        case .pro:
            return state.plan == .plus ? "Upgrade to Pro" : "Choose Pro"
        case .free:
            return ""
        }
    }

    /// "Dec 9", or "your renewal" before the App Store has said.
    private var renewalDay: String {
        state.renewsAt.map { $0.formatted(.dateTime.month(.abbreviated).day()) } ?? "your renewal"
    }

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
