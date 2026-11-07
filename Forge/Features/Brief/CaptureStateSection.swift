import SwiftUI
import SwiftData
import ForgeCore

/// §0A rule: before a Reality Check has run, an idea shows the sky, the
/// original text and one button. The run lives in the app-level center, so
/// leaving this screen does not stop it.
struct CaptureStateSection: View {
    @Bindable var idea: Idea
    @Environment(AppEnvironment.self) private var env
    @AppStorage(AIConsent.storageKey) private var consentStamp: Double = 0

    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            if runner.isRunning {
                progress
            } else {
                RealityCheckButton(idea: idea)
            }
            footnote
        }
        .task { await runner.loadEstimate() }
    }

    private var progress: some View {
        let working = RealityCheckCenter.working(for: runner.phase, lit: runner.litSpheres)
        return VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            HStack(spacing: ForgeSpacing.m) {
                ForEach(Sphere.phase3Panel) { s in
                    SphereOrb(sphere: s, size: 44, state: working.contains(s) ? .working : .idle)
                }
            }
            ForEach(RealityCheckCenter.narration(for: runner.phase, lit: runner.litSpheres), id: \.0) { sphere, line in
                Text("\(sphere.displayName) · \(line)").font(.system(size: 14)).foregroundStyle(ForgeColor.ink)
            }
            Text(progressText).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
            Text("Usually one to three minutes. You can leave this screen; the panel keeps working and Home shows when the Brief is ready.")
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var progressText: String {
        switch runner.phase {
        case .researching(let turn, let sources): "Pass \(turn), \(sources) \(sources == 1 ? "page" : "pages") saved to the Library."
        case .prefilling: "Filling in the Lab from what came back."
        case .applying: "Writing it down."
        default: ""
        }
    }

    @ViewBuilder
    private var footnote: some View {
        switch runner.phase {
        case .offline(let m), .failed(let m):
            HStack(alignment: .top) {
                Text(m).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                Spacer()
                Button("OK") { runner.reset() }.font(.caption.weight(.medium))
            }
        case .idle, .done:
            let est = runner.estimate
            Text(consentStamp > 0
                 ? "About \(AISpend.format(est.lowerBound)) to \(AISpend.format(est.upperBound)). Sent through your proxy."
                 : "About \(AISpend.format(est.lowerBound)) to \(AISpend.format(est.upperBound)). The first run asks before sending your idea text to the AI through your proxy.")
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
        default:
            EmptyView()
        }
    }
}
