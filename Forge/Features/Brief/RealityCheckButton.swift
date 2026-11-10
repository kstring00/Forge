import SwiftUI
import SwiftData
import ForgeCore

/// The ember Reality Check button, shared by Home cards, list rows and idea
/// detail, and the one place its copy lives. Nothing is sent on the tap: a
/// free on-device guard runs first (an idea the panel can't research is
/// blocked with one line and no proxy call), then the confirm sheet, and only
/// Send hands the run to the app-level center. No prices here; Settings →
/// Spend has them. When the last run failed or was stopped, the card says so.
struct RealityCheckButton: View {
    let idea: Idea
    var compact = false
    /// A small capsule for list rows: "To the panel".
    var pill = false
    var pillTitle = "To the panel · \(PlanRules.label(checks: PlanRules.current.costs.check))"
    /// The one-line cost disclosure under the primary button; off on cards (decision 0036).
    var showsDisclosure = true
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @State private var confirming = false
    @State private var blocked: IdeaGuard.Verdict?
    @State private var outOfChecks = false

    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }
    private var failure: String? { env.realityChecks.failure(for: idea.id) }

    var body: some View {
        if pill { pillBody } else { fullBody }
    }

    private var pillBody: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button { tap() } label: {
                Text(failure == nil ? pillTitle : "Try again")
                    .font(.system(.footnote, weight: .medium))
                    .foregroundStyle(ForgeColor.ink)
                    .padding(.horizontal, 14).frame(minHeight: 36)
                    .overlay(Capsule().strokeBorder(ForgeColor.line))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(runner.isRunning)
            .opacity(runner.isRunning ? 0.5 : 1)
            .accessibilityLabel("Send to the panel. Opens a confirmation first.")
            if blocked != nil {
                Text(IdeaGuard.blockedLine).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    .multilineTextAlignment(.trailing).frame(maxWidth: 180)
            }
        }
        .sheet(isPresented: $confirming) { confirmSheet }
    }

    /// Decision 0036: the primary action, full width, 44 pt, verb first.
    private var fullBody: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Button { tap() } label: {
                // Decision 0042: every button states its cost.
                PrimaryButtonLabel(title: failure == nil ? "Get the panel's take · \(PlanRules.label(checks: PlanRules.current.costs.check))" : "Try again")
            }
            .buttonStyle(.plain)
            .disabled(runner.isRunning)
            .accessibilityLabel(failure == nil ? "Get the panel's take. Opens a confirmation first." : "Run the check again. Opens a confirmation first.")

            if let failure {
                noticeBox(title: "The last check didn't finish", message: failure, detail: env.realityChecks.failureDetails[idea.id]) { env.realityChecks.dismissFailure(idea.id) }
            } else if outOfChecks {
                outOfChecksBox
            } else if blocked != nil {
                noticeBox(title: "The panel needs more to go on", message: IdeaGuard.blockedLine) { blocked = nil }
            } else if case .overCeiling = runner.phase {
                Text("This month's AI ceiling is reached. Raise it in Settings to run another check.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }

            if showsDisclosure {
                Text(RealityCheckCost.disclosure + " Nothing is sent until you confirm.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .sheet(isPresented: $confirming) { confirmSheet }
    }

    private var confirmSheet: some View {
        AIConfirmSheet(content: .realityCheck(ideaTitle: idea.title, allowance: env.entitlements.balance.line)) { send in
            if send { start() }
        }
    }

    private func noticeBox(title: String, message: String, detail: String? = nil, dismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: ForgeSpacing.s) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(ForgeColor.emberText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                Text(title).font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.ink)
                Text(message).font(.footnote).foregroundStyle(ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let detail {
                    DisclosureGroup {
                        Text(detail).font(.footnote.monospaced()).foregroundStyle(ForgeColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    } label: {
                        Text("Details").font(.footnote.weight(.medium)).foregroundStyle(ForgeColor.inkSecondary)
                    }
                    .tint(ForgeColor.inkSecondary)
                }
            }
            Spacer(minLength: 0)
            Button("Dismiss", action: dismiss)
                .font(.footnote.weight(.medium))
                .foregroundStyle(ForgeColor.inkSecondary)
        }
        .padding(ForgeSpacing.m)
        .background(ForgeColor.canvas, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.5)))
        .accessibilityElement(children: .combine)
    }

    /// Decision 0032, the out-of-checks state: the AI pauses, nothing else does.
    private var outOfChecksBox: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text("You're out of checks for now").font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.ink)
            Text("So the panel can't look into this one yet. \(env.entitlements.balance.resetsText).")
                .font(.subheadline).foregroundStyle(ForgeColor.ink)
            Text("Still free: score it yourself in the Lab, write down what you know, take it straight to Reality, and log and rule on other ideas.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("See plans") { env.showingMembership = true }
                    .font(.system(.subheadline, weight: .semibold)).foregroundStyle(ForgeColor.emberText)
                Spacer()
                Button("Not now") { withAnimation(ForgeMotion.fade) { outOfChecks = false } }
                    .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
        .padding(ForgeSpacing.m)
        .background(ForgeColor.canvas, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.5)))
    }

    /// The guard runs on the phone, for free, before anything else; then the allowance.
    private func tap() {
        let verdict = IdeaGuard.check(idea.originalText + " " + idea.notes)
        guard verdict == .ok else {
            withAnimation(ForgeMotion.fade) { blocked = verdict }
            return
        }
        blocked = nil
        guard env.entitlements.canStartCheck(inFlight: env.realityChecks.runningCount) else {
            if pill { env.showingMembership = true } else { withAnimation(ForgeMotion.fade) { outOfChecks = true } }
            return
        }
        outOfChecks = false
        confirming = true
    }

    private func start() {
        let advantages = (try? context.fetch(FetchDescriptor<Advantage>()))?.map(\.text) ?? []
        let constraints = (try? context.fetch(FetchDescriptor<Constraint>()))?.map(\.text) ?? []
        env.realityChecks.start(idea: idea, context: context, advantages: advantages, constraints: constraints)
    }
}

/// The Stop button on a working card. Cancels the remaining proxy calls; the
/// runner keeps nothing half-finished and says what was already done.
struct StopCheckButton: View {
    let ideaID: UUID
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Button { env.realityChecks.stop(ideaID) } label: {
            Label("Stop", systemImage: "stop.fill")
                .font(.system(.footnote, weight: .medium))
                .foregroundStyle(ForgeColor.ink)
                .padding(.horizontal, 12).frame(height: 32)
                .background(ForgeColor.canvas, in: Capsule())
                .overlay(Capsule().strokeBorder(ForgeColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Stop the Reality Check")
        .accessibilityHint("Cancels what is left. Nothing half-finished is kept.")
    }
}
