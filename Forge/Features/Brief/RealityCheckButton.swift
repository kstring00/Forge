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
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @State private var confirming = false
    @State private var blocked: IdeaGuard.Verdict?

    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }
    private var failure: String? { env.realityChecks.failure(for: idea.id) }

    var body: some View {
        if pill { pillBody } else { fullBody }
    }

    private var pillBody: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Button { tap() } label: {
                Text(failure == nil ? "To the panel" : "Try again")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(ForgeColor.emberText)
                    .padding(.horizontal, 12).frame(height: 32)
                    .overlay(Capsule().strokeBorder(ForgeColor.emberText))
            }
            .buttonStyle(.plain)
            .disabled(runner.isRunning)
            .opacity(runner.isRunning ? 0.5 : 1)
            .accessibilityLabel("Send to the panel. Opens a confirmation first.")
            if blocked != nil {
                Text(IdeaGuard.blockedLine).font(.caption2).foregroundStyle(ForgeColor.inkSecondary)
                    .multilineTextAlignment(.trailing).frame(maxWidth: 180)
            }
        }
        .sheet(isPresented: $confirming) { confirmSheet }
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Button { tap() } label: {
                HStack(alignment: .center, spacing: ForgeSpacing.m) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(failure == nil ? "Reality check" : "Try the reality check again")
                            .font(ForgeType.label).textCase(.uppercase).kerning(1.3)
                            .foregroundStyle(Color(red: 1.0, green: 0.886, blue: 0.839))
                        if !compact {
                            Text("Who already does this, what they charge, what people complain about, and what the panel makes of it.")
                                .font(.system(size: 15)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer()
                    HStack(spacing: -6) { ForEach(Sphere.phase3Panel.prefix(3)) { OrbView(sphere: $0, size: 18) } }
                }
                .padding(compact ? 14 : 18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(runner.isRunning)
            .accessibilityLabel(failure == nil ? "Run a Reality Check. Opens a confirmation first." : "Run the Reality Check again. Opens a confirmation first.")

            if let failure {
                noticeBox(title: "The last check didn't finish", message: failure) { env.realityChecks.dismissFailure(idea.id) }
            } else if blocked != nil {
                noticeBox(title: "The panel needs more to go on", message: IdeaGuard.blockedLine) { blocked = nil }
            } else if case .overCeiling = runner.phase {
                Text("This month's AI ceiling is reached. Raise it in Settings to run another check.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }

            Text(RealityCheckCost.disclosure + " Nothing is sent until you confirm.")
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .sheet(isPresented: $confirming) { confirmSheet }
    }

    private var confirmSheet: some View {
        AIConfirmSheet(content: .realityCheck(ideaTitle: idea.title)) { send in
            if send { start() }
        }
    }

    private func noticeBox(title: String, message: String, dismiss: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: ForgeSpacing.s) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(ForgeColor.emberText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(ForgeColor.ink)
                Text(message).font(.caption).foregroundStyle(ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            Button("Dismiss", action: dismiss)
                .font(.caption.weight(.medium))
                .foregroundStyle(ForgeColor.inkSecondary)
        }
        .padding(ForgeSpacing.m)
        .background(ForgeColor.canvas, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.5)))
        .accessibilityElement(children: .combine)
    }

    /// The guard runs on the phone, for free, before anything else.
    private func tap() {
        let verdict = IdeaGuard.check(idea.originalText + " " + idea.notes)
        guard verdict == .ok else {
            withAnimation(ForgeMotion.fade) { blocked = verdict }
            return
        }
        blocked = nil
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
                .font(.system(size: 13, weight: .medium))
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
