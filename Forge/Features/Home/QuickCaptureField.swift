import SwiftUI
import SwiftData

/// The capture field on Home, with the mic. Return saves; the mic opens the
/// capture sheet in voice mode. Saving never lands on a static card: Home
/// turns the orbs toward the new idea.
struct QuickCaptureField: View {
    var focusOnAppear = false
    /// Home v2: "What if…" in italic serif with the ember mic button.
    var placeholder = "What if…"
    @Environment(\.modelContext) private var context
    @Environment(AppEnvironment.self) private var env
    @State private var text = ""
    @State private var voice = false
    @FocusState private var focused: Bool

    private var empty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        HStack(alignment: .bottom, spacing: ForgeSpacing.s) {
            TextField("", text: $text, prompt: Text(placeholder).font(ForgeType.originalText).foregroundStyle(ForgeColor.inkSecondary), axis: .vertical)
                .lineLimit(1...4)
                .font(ForgeType.body)
                .focused($focused)
                .submitLabel(.done)
                .onSubmit(save)
                .accessibilityLabel("Quick capture")
            Button(action: save) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundStyle(empty ? ForgeColor.inkSecondary : ForgeColor.ember)
            }
            .buttonStyle(.plain)
            .disabled(empty)
            .accessibilityLabel("Save")
            Button { voice = true } label: {
                Image(systemName: "mic.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(ForgeColor.ember, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Speak an idea")
        }
        .padding(.leading, ForgeSpacing.m).padding(.trailing, 10).padding(.vertical, 10)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        .onAppear { if focusOnAppear { focused = true } }
        .sheet(isPresented: $voice) { CaptureSheet(autoStartVoice: true) }
    }

    private func save() {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else { return }
        let idea = Idea(originalText: body)
        context.insert(idea)
        try? context.save()
        text = ""
        focused = false
        env.justCapturedIdeaID = idea.id
    }
}
