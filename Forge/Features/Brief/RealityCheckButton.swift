import SwiftUI
import SwiftData
import ForgeCore

/// The ember Reality Check button, shared by Home cards and idea detail, and
/// the one place its copy lives: what it costs, that the idea text goes to the
/// model, and, when the last run failed, what went wrong. Handles consent on
/// first use and the monthly ceiling, then hands the run to the app-level
/// center so it survives navigation.
struct RealityCheckButton: View {
    let idea: Idea
    var compact = false
    /// A small capsule for list rows: "To the panel · 15¢". The cost stays visible.
    var pill = false
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @Query(sort: \RealityCheck.createdAt, order: .reverse) private var checks: [RealityCheck]
    @State private var showingConsent = false
    @State private var pending = false

    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }
    private var failure: String? { env.realityChecks.failure(for: idea.id) }

    /// Real runs replace the proxy's range as soon as one exists.
    private var averageCost: Double? {
        RealityCheckCost.average(ofRecent: checks.compactMap(\.actualCostUSD))
    }

    var body: some View {
        if pill { pillBody } else { fullBody }
    }

    private var pillBody: some View {
        Button { tap() } label: {
            Text(failure == nil ? "To the panel · \(RealityCheckCost.cents(averageCost ?? runner.estimate.upperBound))" : "Try again")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ForgeColor.emberText)
                .padding(.horizontal, 12).frame(height: 32)
                .overlay(Capsule().strokeBorder(ForgeColor.emberText))
        }
        .buttonStyle(.plain)
        .disabled(runner.isRunning)
        .opacity(runner.isRunning ? 0.5 : 1)
        .accessibilityLabel("Send to the panel. Runs on AI, your idea text is sent to the model.")
        .task { await runner.loadEstimate() }
        .sheet(isPresented: $showingConsent) { consentSheet }
    }

    private var consentSheet: some View {
        AIConsentSheet { agreed in
            showingConsent = false
            if agreed {
                AIConsent.grant()
                if pending { pending = false; start() }
            } else {
                pending = false
            }
        }
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
            .accessibilityLabel(failure == nil ? "Run a Reality Check" : "Run the Reality Check again")

            if let failure {
                failureBox(failure)
            } else if case .overCeiling(let estimate, let remaining) = runner.phase {
                Text("This check could cost about \(RealityCheckCost.cents(estimate)); \(AISpend.format(remaining)) is left under this month's ceiling. Raise it in Settings.")
                    .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            }

            Text(RealityCheckCost.disclosure(estimate: runner.estimate, average: averageCost))
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .task { await runner.loadEstimate() }
        .sheet(isPresented: $showingConsent) { consentSheet }
    }

    private func failureBox(_ message: String) -> some View {
        HStack(alignment: .top, spacing: ForgeSpacing.s) {
            Image(systemName: "exclamationmark.circle")
                .foregroundStyle(ForgeColor.emberText)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                Text("The last check didn't finish").font(.caption.weight(.semibold)).foregroundStyle(ForgeColor.ink)
                Text(message).font(.caption).foregroundStyle(ForgeColor.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            Button("Dismiss") { env.realityChecks.dismissFailure(idea.id) }
                .font(.caption.weight(.medium))
                .foregroundStyle(ForgeColor.inkSecondary)
        }
        .padding(ForgeSpacing.m)
        .background(ForgeColor.canvas, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.5)))
        .accessibilityElement(children: .combine)
    }

    private func tap() {
        guard AIConsent.isGranted else {
            pending = true
            showingConsent = true
            return
        }
        start()
    }

    private func start() {
        let advantages = (try? context.fetch(FetchDescriptor<Advantage>()))?.map(\.text) ?? []
        let constraints = (try? context.fetch(FetchDescriptor<Constraint>()))?.map(\.text) ?? []
        env.realityChecks.start(idea: idea, context: context, advantages: advantages, constraints: constraints)
    }
}
