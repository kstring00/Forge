import SwiftUI
import SwiftData
import ForgeCore

/// §0A rule: before a Reality Check has run, an idea shows the sky, the
/// original text and one button. The run lives in the app-level center, so
/// leaving this screen does not stop it.
struct CaptureStateSection: View {
    @Bindable var idea: Idea
    @Environment(AppEnvironment.self) private var env

    private var runner: RealityCheckRunner { env.realityChecks.runner(for: idea.id) }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            // The button carries the cost line and any failure, the same on every surface.
            if runner.isRunning {
                progress
            } else {
                RealityCheckButton(idea: idea)
            }
        }
    }

    private var progress: some View {
        let working = RealityCheckCenter.working(for: runner.phase, lit: runner.litSpheres)
        return VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            HStack(spacing: ForgeSpacing.m) {
                ForEach(Sphere.phase3Panel) { s in
                    OrbView(sphere: s, state: working.contains(s) ? .working : .idle, size: 44)
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
        case .researching(let turn, let sources): "Pass \(turn), \(sources) \(sources == 1 ? "page" : "pages") found so far."
        case .prefilling: "Filling in the Lab from what came back."
        case .applying: "Writing it down."
        default: ""
        }
    }
}
