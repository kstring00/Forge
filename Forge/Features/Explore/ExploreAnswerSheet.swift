import SwiftUI
import ForgeCore

struct ExploreAnswerSheet: View {
    let prompt: ExplorePrompt
    let idea: Idea
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(prompt: ExplorePrompt, idea: Idea) {
        self.prompt = prompt
        self.idea = idea
        let latest = ExploreActions.latest(for: prompt.key, on: idea)
        let user = latest?.userText ?? ""
        _text = State(initialValue: user.isEmpty ? (latest?.aiText ?? "") : user)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                if let sphere = prompt.sphere {
                    HStack(spacing: ForgeSpacing.s) {
                        Circle().fill(OrbView.palette(for: sphere).base).frame(width: 8, height: 8)
                        Text("Asked by the \(sphere.displayName)").forgeLabel()
                    }
                }
                Text(prompt.question)
                    .font(ForgeType.ideaTitle)
                    .foregroundStyle(ForgeColor.ink)
                Text(prompt.hint)
                    .font(ForgeType.secondary)
                    .foregroundStyle(ForgeColor.inkSecondary)
                TextEditor(text: $text)
                    .font(ForgeType.body)
                    .scrollContentBackground(.hidden)
                    .padding(ForgeSpacing.s)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                    .focused($focused)
                    .accessibilityLabel(prompt.question)
            }
            .padding(ForgeSpacing.m)
            .background(ForgeColor.canvas)
            .navigationTitle("Explore")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        ExploreActions.answer(text, promptKey: prompt.key, on: idea)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
