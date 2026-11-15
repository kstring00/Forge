import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0028: after the first capture, "Want the panel to look into
/// this?" with "Look into it · free", the AI-sharing line, and "Not yet, just
/// save it". Tapping Look into it records consent and runs the check; the
/// proxy makes it free and counts it against nothing. The eight-word guard
/// runs first, so a thin idea never spends it.
struct FirstCheckSheet: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    private var guardVerdict: IdeaGuard.Verdict { IdeaGuard.check(idea.originalText + " " + idea.notes) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    HStack(spacing: ForgeSpacing.m) {
                        ForEach(Panel.order) { s in OrbView(sphere: s, state: s == .steward ? .dormant : .idle, size: 36) }
                    }
                    .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                        Text("Your first check").forgeLabel().foregroundStyle(ForgeColor.emberText)
                        Text(Spheres.afterCaptureLine).font(ForgeType.ideaTitleHero).foregroundStyle(ForgeColor.ink)
                        Text(idea.title).font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink.opacity(0.85)).lineLimit(3)
                    }
                    Text("Five voices read the web about it: who already does this, what they charge, what people complain about. Then a verdict and your first step. One to three minutes; you can leave and come back.")
                        .font(ForgeType.body).foregroundStyle(ForgeColor.ink.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)

                    if guardVerdict != .ok {
                        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                            Text("The panel needs more to go on").font(.subheadline.weight(.semibold)).foregroundStyle(ForgeColor.ink)
                            Text(IdeaGuard.blockedLine).font(.system(.subheadline)).foregroundStyle(ForgeColor.ink)
                            Text("Your free check is still yours. Add to the idea, then send it from its page.").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                        }
                        .padding(ForgeSpacing.m)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                        Button { dismiss() } label: {
                            Text("Save it for now").frame(maxWidth: .infinity).modifier(SecondaryButtonChrome())
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { lookIntoIt() } label: {
                            HStack(spacing: 6) {
                                Text("Look into it").font(.system(.body, weight: .semibold))
                                Text("· free").font(.system(.body, weight: .regular)).opacity(0.9)
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Look into it, free")
                        Text("Your idea text goes to an AI model through the app's own server. Nothing else from your phone goes with it. The full list of what is and isn't sent is in Settings → AI, where you can withdraw this.")
                            .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Button { dismiss() } label: {
                            Text("Not yet, just save it").font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.inkSecondary)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(ForgeSpacing.l)
                .padding(.top, ForgeSpacing.m)
            }
            .background(ForgeColor.canvas)
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func lookIntoIt() {
        guard env.entitlements.canStartCheck(inFlight: env.realityChecks.runningCount) else {
            dismiss()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { env.showingMembership = true }
            return
        }
        AIConsent.grant()
        let advantages = (try? context.fetch(FetchDescriptor<Advantage>()))?.map(\.text) ?? []
        let constraints = (try? context.fetch(FetchDescriptor<Constraint>()))?.map(\.text) ?? []
        env.realityChecks.start(idea: idea, context: context, advantages: advantages, constraints: constraints)
        dismiss()
    }
}

/// Looks the idea up so the sheet can be driven by an id from the environment.
struct FirstCheckDestination: View {
    @Query private var ideas: [Idea]

    init(id: UUID) {
        _ideas = Query(filter: #Predicate<Idea> { $0.id == id })
    }

    var body: some View {
        if let idea = ideas.first { FirstCheckSheet(idea: idea) }
    }
}

/// A one-time callout on the first Brief (decision 0028). An X dismisses it for good.
struct FirstRunCallout: View {
    let step: FirstRun.GuideStep
    let text: String
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        if env.firstRun.showsGuide(step) {
            HStack(alignment: .top, spacing: ForgeSpacing.s) {
                SparkGlyph().padding(.top, 2)
                Text(text).font(.system(.footnote)).foregroundStyle(ForgeColor.ink).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: ForgeSpacing.s)
                Button { withAnimation(ForgeMotion.fade) { env.firstRun.dismiss(step) } } label: {
                    Image(systemName: "xmark").font(.footnote.weight(.semibold)).foregroundStyle(ForgeColor.inkSecondary).frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }
            .padding(.horizontal, ForgeSpacing.m).padding(.vertical, ForgeSpacing.s + 2)
            .background(ForgeColor.ember.opacity(0.10), in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.ember.opacity(0.5)))
            .transition(.opacity)
        }
    }
}
