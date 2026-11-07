import SwiftUI

/// The one question the Journal asks: "What actually happened?"
struct OutcomeSheet: View {
    let title: String
    let subject: String
    var showsNextStep = false
    var onSave: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var whatHappened = ""
    @State private var nextStep = ""
    @FocusState private var focused: Bool

    private var canSave: Bool { !whatHappened.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                Text(subject)
                    .font(ForgeType.ideaTitle)
                    .foregroundStyle(ForgeColor.ink)
                Text("What actually happened?").forgeLabel()
                TextEditor(text: $whatHappened)
                    .font(ForgeType.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(ForgeSpacing.s)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                    .focused($focused)
                    .accessibilityLabel("What actually happened")
                if showsNextStep {
                    Text("And the one next thing").forgeLabel()
                    TextField("Leave empty to decide later", text: $nextStep, axis: .vertical)
                        .lineLimit(1...4)
                        .font(ForgeType.body)
                        .padding(ForgeSpacing.m)
                        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                        .accessibilityLabel("Next step")
                }
                Text("Stored next to what you expected. Nothing is scored.")
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
                Spacer()
            }
            .padding(ForgeSpacing.m)
            .background(ForgeColor.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(whatHappened, showsNextStep ? nextStep : nil)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
    }
}
