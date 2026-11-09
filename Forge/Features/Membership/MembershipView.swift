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
                statusCard
                periodToggle
                plusCard
                proCard
                freeCard
                topUpRow
                promises
                legal
            }
            .padding(.horizontal, 20)
            .padding(.bottom, ForgeSpacing.xxl)
        }
        .background(alignment: .top) {
            SkyHeader().frame(height: 340).ignoresSafeArea()
        }
        .background(ForgeColor.canvas)
        .overlay(alignment: .bottom) { banner }
        .manageSubscriptionsSheet(isPresented: $managing)
        .sheet(isPresented: $showingPrivacy) { PrivacySummarySheet() }
        .task { await store.load() }
    }

    // MARK: Hero

    private var hero: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
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
            Text("Hunch Plus").forgeLabel().foregroundStyle(.white.opacity(0.85)).padding(.top, ForgeSpacing.xl)
            Text("Stop guessing which idea is worth it")
                .font(Font.custom("Fraunces-SemiBold", size: 34, relativeTo: .largeTitle))
                .foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
            Text("Less than a couple of coffees a month, against months lost on the wrong idea.")
                .font(.system(.body)).foregroundStyle(ForgeColor.ink.opacity(0.9))
                .shadow(color: .black.opacity(0.3), radius: 6, y: 1)
        }
        .padding(.bottom, ForgeSpacing.s)
    }

    // MARK: Where you are

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack {
                Text(statusLabel).forgeLabel()
                Spacer()
                Text(balance.resetsText).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(balance.monthlyLeft) of \(balance.monthlyAllowance)").font(ForgeType.numeralMedium).foregroundStyle(ForgeColor.ink)
                Text(state.plan == .free ? "free \(balance.monthlyAllowance == 1 ? "check" : "checks") left this month" : "checks left this month")
                    .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(ForgeColor.line)
                    Capsule().fill(ForgeColor.ember)
                        .frame(width: geo.size.width * Double(balance.monthlyLeft) / Double(max(1, balance.monthlyAllowance)))
                }
            }
            .frame(height: 5)
            if balance.rolledOverLeft > 0 {
                Text("+\(balance.rolledOverLeft) carried over from last month, used first. They expire \(balance.expiresText).")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            if balance.topUps > 0 {
                Text("+\(balance.topUps) extra \(balance.topUps == 1 ? "check" : "checks"), used after these. They never expire.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            if balance.firstFreeAvailable {
                Text("Your first check on this phone is free and doesn't count.").font(.footnote).foregroundStyle(ForgeColor.emberText)
            }
        }
        .padding(ForgeSpacing.cardPadding)
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

    private var plusCard: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            HStack(alignment: .top) {
                Text("Plus").font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                Spacer()
                priceBlock(plusID, otherLine: period == .yearly
                           ? "\(store.perMonth(plusID)) a month · or \(store.price(MembershipProduct.plusMonthly)) monthly"
                           : "or \(store.price(plusYearlyID)) a year\(store.showsFoundingOffer ? " as a founding member" : "")")
            }
            Text("15 checks a month. About 15 ideas looked at properly.")
                .font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.ink)
            VStack(alignment: .leading, spacing: 8) {
                check("Argue it out with the panel when you disagree")
                check("Your patterns: learn where your instincts are right")
                check("The Library: every source, ask it anything")
            }
            primaryButton(plusTitle, id: plusID, emphasised: true)
            Text(plusFinePrint).font(.footnote).foregroundStyle(ForgeColor.inkSecondary).frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
        }
        .padding(ForgeSpacing.cardPadding)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.ember, lineWidth: 1.5))
        .overlay(alignment: .topLeading) {
            Text(founding ? "Founding member price" : "Most people pick this")
                .font(.system(.footnote, weight: .semibold)).foregroundStyle(.white)
                .padding(.horizontal, 10).padding(.vertical, 3)
                .background(ForgeColor.ember, in: Capsule())
                .offset(x: 16, y: -12)
        }
        .padding(.top, 12)
    }

    private var plusTitle: String {
        if state.productID == plusID { return "Your plan · Manage" }
        if state.plan == .plus { return "Switch to \(period == .yearly ? "yearly" : "monthly")" }
        if state.plan == .pro { return "Switch to Plus" }
        if founding { return "Join as a founding member" }
        if period == .yearly && store.trialEligible { return "Try Plus free for 7 days" }
        return "Choose Plus"
    }

    private var plusFinePrint: String {
        if founding { return "\(store.price(plusID)) a year, kept for as long as you stay subscribed. Cancel anytime in Settings." }
        if period == .yearly && store.trialEligible && state.plan == .free {
            return "Then \(store.price(plusID)) a year. Up to \(MembershipState.trialChecks) checks during the trial. Cancel anytime in Settings."
        }
        return "\(store.price(plusID)) a \(period == .yearly ? "year" : "month"). Cancel anytime in Settings."
    }

    private var proCard: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            HStack(alignment: .top) {
                Text("Pro").font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                Spacer()
                priceBlock(proID, otherLine: period == .yearly ? "or \(store.price(MembershipProduct.proMonthly)) monthly" : "or \(store.price(MembershipProduct.proYearly)) a year")
            }
            Text("60 checks a month, faster answers and deeper research. For when ideas are your job.")
                .font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            primaryButton(proTitle, id: proID, emphasised: false)
        }
        .padding(ForgeSpacing.cardPadding)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var proTitle: String {
        if state.productID == proID { return "Your plan · Manage" }
        if state.plan == .pro { return "Switch to \(period == .yearly ? "yearly" : "monthly")" }
        if state.plan == .plus { return "Upgrade to Pro" }
        return "Choose Pro"
    }

    private var freeCard: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack {
                Text("Free").font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                Spacer()
                Text(state.plan == .free ? "Your plan" : "$0").font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.ink)
            }
            Text("1 check a month, each with its Sparks. Once an idea is checked, its launch plan and re-scores are included. Catching ideas, your steps and the Journal are free forever.")
                .font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
            if state.plan != .free {
                Button("To go back to Free, cancel in Manage subscription") { managing = true }
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
        .padding(ForgeSpacing.cardPadding)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var topUpRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Busy month?").font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                Text("\(MembershipProduct.topUpChecks) extra checks, never expire").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            Spacer()
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
        .padding(ForgeSpacing.cardPadding)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var promises: some View {
        VStack(alignment: .leading, spacing: 10) {
            promise("Your ideas, steps and Journal are always yours, on every plan.")
            promise("If a check fails partway, it doesn't count.")
            promise("Unused monthly checks reset; extra checks you buy never expire.")
        }
        .padding(.top, ForgeSpacing.s)
    }

    private var legal: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("Subscriptions renew automatically at the price shown unless cancelled at least 24 hours before the period ends. Payment is charged to your Apple ID. Manage or cancel in your Apple account settings. Checks use AI: your idea text is sent to a model through Hunch's server.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: ForgeSpacing.l) {
                Button("Terms") { openURL(LegalLinks.terms) }
                Button("Privacy") {
                    if let url = LegalLinks.privacy { openURL(url) } else { showingPrivacy = true }
                }
                if state.plan != .free { Button("Manage subscription") { managing = true } }
            }
            .font(.system(.footnote, weight: .medium)).foregroundStyle(ForgeColor.emberText).underline()
        }
        .padding(.top, ForgeSpacing.m)
    }

    // MARK: Pieces

    private func priceBlock(_ id: String, otherLine: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(store.price(id)).font(.system(.title3, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                Text(id.hasSuffix("yearly") ? "/ year" : "/ month").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
            Text(otherLine).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
        }
    }

    private func check(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark").font(.system(.footnote, weight: .bold)).foregroundStyle(ForgeColor.emberText).padding(.top, 2)
            Text(text).font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func promise(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(ForgeColor.ember).frame(width: 6, height: 6).padding(.top, 7)
            Text(text).font(.subheadline).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
        }
    }

    private func primaryButton(_ title: String, id: String, emphasised: Bool) -> some View {
        let current = state.productID == id
        return Button {
            if current { managing = true } else { Task { await store.purchase(id) } }
        } label: {
            Group {
                if store.purchasing == id { ProgressView().tint(emphasised ? .white : ForgeColor.ink) } else { Text(title) }
            }
            .font(.system(.body, weight: .semibold))
            .foregroundStyle(emphasised && !current ? .white : ForgeColor.ink)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(emphasised && !current ? ForgeColor.ember : ForgeColor.canvas, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(emphasised && !current ? Color.clear : ForgeColor.line))
        }
        .buttonStyle(.plain)
        .disabled(store.purchasing != nil)
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
