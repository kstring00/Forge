import SwiftUI
import SwiftData

/// Phase 0 shell: text capture only, so the store can be exercised on device.
/// Phase 1 adds voice, speech-to-text and paste, and the transcript correction window.
struct CaptureSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @FocusState private var focused: Bool

    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text("Raw thought").forgeLabel()
                TextEditor(text: $text)
                    .font(ForgeType.body)
                    .scrollContentBackground(.hidden)
                    .padding(ForgeSpacing.s)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .focused($focused)
                    .accessibilityLabel("Idea text")
                Text("Saved exactly as written. You can add a title and notes later; this text never changes.")
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
            .padding(ForgeSpacing.m)
            .background(ForgeColor.canvas)
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let idea = Idea(originalText: text)
        context.insert(idea)
        dismiss()
    }
}
