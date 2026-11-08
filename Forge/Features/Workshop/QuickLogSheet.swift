import SwiftUI
import SwiftData
import ForgeCore

/// The default way to log a conversation: one field, typed or spoken. The
/// rung comes from the words (time, money, came back; never below time), the
/// person can change it, and Save makes the user-verified source, advances
/// the count and writes the Journal line. The question-by-question sheet stays
/// behind Questions.
struct QuickLogSheet: View {
    @Bindable var project: Project
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @State private var text = ""
    @State private var rung: Int?
    @State private var saved: (rung: Int, count: Int)?
    @FocusState private var focused: Bool

    private var speech: SpeechCapture { env.speech }
    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var effectiveRung: Int { max(3, rung ?? RungInference.rungForConversation(text)) }

    var body: some View {
        NavigationStack {
            Group {
                if let saved { confirmation(saved) } else { form }
            }
            .background(ForgeColor.canvas)
            .navigationTitle(saved == nil ? "Log a conversation" : "Saved")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if saved == nil {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { speech.discardRecording(); dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") { save() }.disabled(trimmed.isEmpty || speech.isRecording).fontWeight(.semibold)
                    }
                }
            }
            .onAppear { focused = true }
            .onDisappear { if speech.isRecording { speech.discardRecording() } }
            .interactiveDismissDisabled(speech.isRecording)
        }
        .presentationDetents([.medium, .large])
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                if let step = project.nextStep {
                    Text(step).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
                VoiceNoteField(label: "Who did you talk to, and what did they say?", text: $text, focused: $focused, minHeight: 140)
                HStack(spacing: 6) {
                    Text("Counts as").font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
                    Menu {
                        ForEach([3, 4, 5], id: \.self) { r in
                            Button { rung = r } label: {
                                if r == effectiveRung { Label(RungInference.label(r), systemImage: "checkmark") } else { Text(RungInference.label(r)) }
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(RungInference.label(effectiveRung)).font(.system(.subheadline, weight: .semibold))
                            Image(systemName: "chevron.up.chevron.down").font(.footnote)
                        }
                        .foregroundStyle(ForgeColor.emberText)
                    }
                    .accessibilityLabel("Counts as \(RungInference.label(effectiveRung)). Change.")
                    Spacer()
                }
                Text("Read from your words; change it if it's wrong. Saved as verified by you, counted toward \(project.effectiveTarget), and written to the Journal.")
                    .font(.footnote).foregroundStyle(ForgeColor.inkSecondary).fixedSize(horizontal: false, vertical: true)
            }
            .padding(ForgeSpacing.m)
        }
    }

    private func save() {
        let audio = speech.recordingURL?.lastPathComponent
        speech.reset()
        let r = effectiveRung
        WorkshopActions.logConversation(project, whatHappened: trimmed, rung: r, audioFileName: audio, in: context)
        try? context.save()
        focused = false
        withAnimation(ForgeMotion.settle) { saved = (r, min(project.nextStepCount, project.effectiveTarget)) }
    }

    private func confirmation(_ s: (rung: Int, count: Int)) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            Image(systemName: "checkmark.circle.fill").font(.system(size: 44)).foregroundStyle(ForgeColor.ember)
                .accessibilityHidden(true)
            Text("Saved · \(RungInference.label(s.rung)) · \(s.count) of \(project.effectiveTarget)").forgeSubhead()
            Text("In the Journal, and saved as verified by you on what this step tests.")
                .font(.subheadline).foregroundStyle(ForgeColor.inkSecondary)
            Button { dismiss() } label: {
                Text("Close")
                    .font(.system(.body, weight: .semibold)).foregroundStyle(.white)
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, ForgeSpacing.s)
            Spacer()
        }
        .padding(ForgeSpacing.l)
    }
}
