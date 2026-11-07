import SwiftUI
import SwiftData
import ForgeCore

/// §0A rule: before a Reality Check has run, an idea shows the sky, the
/// original text and one button. Nothing else above the fold.
struct CaptureStateSection: View {
    @Bindable var idea: Idea
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @AppStorage(AIConsent.storageKey) private var consentStamp: Double = 0
    @State private var runner: RealityCheckRunner?
    @State private var showingConsent = false
    @State private var pending = false

    private var phase: RealityCheckRunner.Phase { runner?.phase ?? .idle }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            switch phase {
            case .researching, .prefilling, .applying:
                progress
            default:
                button
            }
            footnote
        }
        .task {
            if runner == nil { runner = RealityCheckRunner(proxy: env.ai as? ProxyAIClient) }
            await runner?.loadEstimate()
        }
        .sheet(isPresented: $showingConsent) {
            AIConsentSheet { agreed in
                showingConsent = false
                if agreed {
                    AIConsent.grant()
                    consentStamp = AIConsent.grantedAt?.timeIntervalSince1970 ?? 0
                    if pending { pending = false; Task { await start() } }
                } else {
                    pending = false
                }
            }
        }
    }

    private var button: some View {
        Button { Task { await tap() } } label: {
            HStack(alignment: .center, spacing: ForgeSpacing.m) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reality check").font(ForgeType.label).textCase(.uppercase).kerning(1.3).foregroundStyle(Color(red: 1.0, green: 0.886, blue: 0.839))
                    Text("Who already does this, what they charge, what people complain about, and what the panel makes of it.")
                        .font(.system(size: 15)).foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                HStack(spacing: -6) { ForEach(Sphere.phase3Panel.prefix(3)) { SphereOrb(sphere: $0, size: 18) } }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Run a Reality Check")
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            HStack(spacing: ForgeSpacing.m) {
                ForEach(Sphere.phase3Panel) { s in
                    SphereOrb(sphere: s, size: 44, state: (runner?.litSpheres.contains(s) ?? false) ? .idle : .working)
                }
            }
            Text(progressText).font(.system(size: 14)).foregroundStyle(ForgeColor.ink)
            Text("Usually one to three minutes. You can leave this screen; it keeps going.")
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
        }
        .padding(ForgeSpacing.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private var progressText: String {
        switch phase {
        case .researching(let turn, let sources): "Reading the market. Pass \(turn), \(sources) \(sources == 1 ? "page" : "pages") saved to the Library."
        case .prefilling: "The Spheres are reading what came back and filling in the Lab."
        case .applying: "Writing it down."
        default: ""
        }
    }

    @ViewBuilder
    private var footnote: some View {
        switch phase {
        case .offline(let m), .failed(let m):
            HStack(alignment: .top) {
                Text(m).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                Spacer()
                Button("OK") { runner?.reset() }.font(.caption.weight(.medium))
            }
        case .overCeiling(let estimate, let remaining):
            Text("This check could cost about \(AISpend.format(estimate)); \(AISpend.format(remaining)) is left under this month's ceiling. Raise it in Settings.")
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
        case .idle, .done:
            let est = runner?.estimate ?? 0.15...0.60
            Text(consentStamp > 0
                 ? "About \(AISpend.format(est.lowerBound)) to \(AISpend.format(est.upperBound)). Sent through your proxy."
                 : "About \(AISpend.format(est.lowerBound)) to \(AISpend.format(est.upperBound)). The first run asks before sending your idea text to the AI through your proxy.")
                .font(.caption).foregroundStyle(ForgeColor.inkSecondary)
        default:
            EmptyView()
        }
    }

    private func tap() async {
        guard AIConsent.isGranted else {
            pending = true
            showingConsent = true
            return
        }
        await start()
    }

    private func start() async {
        if runner == nil { runner = RealityCheckRunner(proxy: env.ai as? ProxyAIClient) }
        let advantages = (try? context.fetch(FetchDescriptor<Advantage>()))?.map(\.text) ?? []
        let constraints = (try? context.fetch(FetchDescriptor<Constraint>()))?.map(\.text) ?? []
        await runner?.run(on: idea, in: context, advantages: advantages, constraints: constraints)
    }
}
