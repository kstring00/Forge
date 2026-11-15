import SwiftUI
import SwiftData
import ForgeCore

/// Decision 0028: the first screen. The six orbs, one line, and the way in.
/// The bundled example sits behind one small link and nowhere else.
struct WelcomeView: View {
    @Environment(AppEnvironment.self) private var env
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var ideas: [Idea]

    var body: some View {
        ZStack(alignment: .top) {
            ForgeColor.canvas.ignoresSafeArea()
            SkyHeader().frame(height: 300).frame(maxHeight: .infinity, alignment: .top).ignoresSafeArea()
            VStack(alignment: .leading, spacing: ForgeSpacing.xl) {
                Spacer(minLength: 80)
                Text("Welcome").forgeLabel().foregroundStyle(.white.opacity(0.9))
                Text("Six perspectives\non every hunch")
                    .font(Font.custom("Fraunces-SemiBold", size: 40, relativeTo: .largeTitle))
                    .foregroundStyle(ForgeColor.ink)
                    .lineSpacing(-2)
                EmptyPanel()
                VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                    Text("Catch an idea in your own words. If you want, the panel reads the web about it, argues, and comes back with a verdict and your first step. Your first check is on us.")
                        .font(ForgeType.body).foregroundStyle(ForgeColor.ink.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(spacing: ForgeSpacing.m) {
                    Button {
                        env.firstRun.markWelcomeSeen()
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { env.capture = .text }
                    } label: {
                        Text("Capture your first hunch")
                            .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                            .frame(maxWidth: .infinity).frame(height: 52)
                            .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    Button { seeExample() } label: {
                        Text("No idea right now? See an example")
                            .font(.system(.subheadline, weight: .medium)).foregroundStyle(ForgeColor.inkSecondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, ForgeSpacing.l)
            .padding(.bottom, ForgeSpacing.xl)
        }
        .interactiveDismissDisabled(true)
    }

    /// The example becomes an ordinary idea, then the free-check screen asks about it.
    private func seeExample() {
        env.firstRun.markWelcomeSeen()
        let idea = ideas.first { $0.originalText == ExampleIdea.text } ?? {
            let i = Idea(originalText: ExampleIdea.text, title: ExampleIdea.title)
            i.lensType = .business
            context.insert(i)
            try? context.save()
            return i
        }()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { env.justCapturedIdeaID = idea.id }
    }
}
