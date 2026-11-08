import SwiftUI
import ForgeCore

/// The Explore stage inside idea detail: six guided prompts, the AI notes the
/// user has accepted, and the Expand / Summarize actions behind consent.
struct ExploreSection: View {
    @Bindable var idea: Idea
    @Environment(AppEnvironment.self) private var env
    @AppStorage(AIConsent.storageKey) private var consentStamp: Double = 0

    @State private var editing: ExplorePrompt?
    @State private var controller: ExploreAIController?
    @State private var pendingAction: AIAction?

    private var answered: Int { ExploreActions.answeredCount(on: idea) }
    private var aiNotes: [Exploration] { ExploreActions.aiNotes(on: idea) }
    private var state: ExploreAIController.State { controller?.state ?? .idle }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            HStack {
                Text("Explore").forgeLabel()
                Spacer()
                Text("Optional").forgeLabel()
            }

            VStack(spacing: ForgeSpacing.s) {
                ForEach(ExplorePrompts.all) { prompt in
                    promptRow(prompt)
                }
            }

            if !aiNotes.isEmpty {
                VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                    Text("AI notes").forgeLabel()
                    ForEach(aiNotes) { note in
                        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                            Text(ExplorePrompts.aiLabel(for: note.promptKey)).forgeLabel()
                            AIText(text: note.aiText ?? "")
                        }
                    }
                }
            }

            aiActions
        }
        .sheet(item: $editing) { prompt in
            ExploreAnswerSheet(prompt: prompt, idea: idea)
        }
        .sheet(item: $pendingAction) { action in
            AIConfirmSheet(content: action == .expand ? .expand : .summarize) { send in
                consentStamp = AIConsent.grantedAt?.timeIntervalSince1970 ?? 0
                if send { Task { await run(action) } }
            }
        }
        .sheet(isPresented: proposalPresented) {
            if case .proposal(let proposal) = state, let controller {
                AIProposalSheet(proposal: proposal, idea: idea,
                                onAccept: { controller.accept(into: idea) },
                                onDiscard: { controller.discard() })
            }
        }
    }

    // MARK: Rows

    private func promptRow(_ prompt: ExplorePrompt) -> some View {
        let latest = ExploreActions.latest(for: prompt.key, on: idea)
        let answer = latest?.userText ?? ""
        let proposed = answer.isEmpty ? (latest?.aiText ?? "") : ""
        return Button {
            editing = prompt
        } label: {
            HStack(alignment: .top, spacing: ForgeSpacing.m) {
                if let sphere = prompt.sphere {
                    Circle().fill(OrbView.palette(for: sphere).base).frame(width: 8, height: 8).padding(.top, 7)
                        .accessibilityLabel("Asked by the \(sphere.displayName)")
                } else {
                    Color.clear.frame(width: 16, height: 16)
                }
                VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                    Text(prompt.question)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(ForgeColor.ink)
                    if !proposed.isEmpty {
                        AIText(text: proposed)
                    } else if answer.isEmpty {
                        Text(prompt.hint)
                            .font(.footnote)
                            .foregroundStyle(ForgeColor.inkSecondary)
                    } else {
                        Text(answer)
                            .font(ForgeType.body)
                            .foregroundStyle(ForgeColor.ink)
                    }
                }
                Spacer(minLength: ForgeSpacing.s)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
            .padding(ForgeSpacing.m)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(prompt.question)
        .accessibilityValue(!proposed.isEmpty ? "Proposed by the panel: \(proposed)" : (answer.isEmpty ? "Not answered" : answer))
    }

    // MARK: AI

    private var aiActions: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(spacing: ForgeSpacing.m) {
                aiButton("Expand", symbol: "sparkle") { await start(.expand) }
                aiButton("Summarize", symbol: "text.alignleft") { await start(.summarize) }
                    .disabled(answered == 0)
                Spacer()
                if case .running = state { ProgressView().controlSize(.small) }
            }
            switch state {
            case .offline(let message), .failed(let message):
                HStack(alignment: .top, spacing: ForgeSpacing.s) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(ForgeColor.inkSecondary)
                    Spacer()
                    Button("OK") { controller?.dismissMessage() }
                        .font(.caption.weight(.medium))
                }
            case .running:
                Text("Thinking. Nothing is saved until you accept.")
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
            default:
                Text("AI proposals are shown in full and saved only when you accept them.")
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
        }
    }

    private func aiButton(_ title: String, symbol: String, action: @escaping () async -> Void) -> some View {
        Button {
            Task { await action() }
        } label: {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, ForgeSpacing.m)
                .padding(.vertical, ForgeSpacing.s)
                .foregroundStyle(ForgeColor.ink)
                .background(ForgeColor.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(ForgeColor.line))
        }
        .buttonStyle(.plain)
        .disabled(controller?.isRunning ?? false)
    }

    private var proposalPresented: Binding<Bool> {
        Binding(
            get: { if case .proposal = state { return true } else { return false } },
            set: { if !$0 { controller?.discard() } }
        )
    }

    private func ensureController() -> ExploreAIController {
        if let controller { return controller }
        let c = ExploreAIController(client: env.ai)
        controller = c
        return c
    }

    /// Every AI action opens the confirm sheet first; nothing is sent until Send.
    private func start(_ action: AIAction) async {
        pendingAction = action
    }

    private func run(_ action: AIAction) async {
        let c = ensureController()
        switch action {
        case .expand: await c.expand(idea)
        case .summarize: await c.summarize(idea)
        default: break
        }
    }
}

extension AIAction: Identifiable {
    public var id: String { rawValue }
}
