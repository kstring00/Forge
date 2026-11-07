import SwiftUI
import SwiftData

/// Capture in seconds: type, paste, or speak. A voice transcript stays
/// editable until Save (decision 0005); after Save the text never changes.
struct CaptureSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env

    @State private var text = ""
    /// Text present before the current voice session, so dictation appends.
    @State private var textBeforeVoice = ""
    @State private var usedVoice = false
    @State private var saved = false
    @State private var errorText: String?
    @FocusState private var focused: Bool

    private var speech: SpeechCapture { env.speech }
    private var canSave: Bool { !speech.isRecording && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                Text(speech.isRecording ? "Listening" : "Raw thought").forgeLabel()

                TextEditor(text: $text)
                    .font(ForgeType.body)
                    .scrollContentBackground(.hidden)
                    .padding(ForgeSpacing.s)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous)
                            .strokeBorder(speech.isRecording ? ForgeColor.ember.opacity(0.6) : ForgeColor.line)
                    )
                    .disabled(speech.isRecording)
                    .focused($focused)
                    .accessibilityLabel("Idea text")

                if speech.isRecording {
                    listeningRow
                }

                if let errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(ForgeColor.inkSecondary)
                }

                HStack(spacing: ForgeSpacing.m) {
                    PasteButton(payloadType: String.self) { strings in
                        guard let pasted = strings.first, !pasted.isEmpty else { return }
                        append(pasted)
                    }
                    .buttonBorderShape(.capsule)
                    .labelStyle(.titleAndIcon)
                    .tint(ForgeColor.ink)
                    .disabled(speech.isRecording)

                    Spacer()

                    voiceButton
                }
                .padding(.top, ForgeSpacing.xs)

                Text(usedVoice
                     ? "Fix any transcription mistakes now. After you save, this text never changes."
                     : "Saved exactly as written. You can add a title and notes later; this text never changes.")
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
            }
            .padding(ForgeSpacing.m)
            .background(ForgeColor.canvas)
            .navigationTitle("Capture")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { cancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
            .onDisappear {
                if !saved { speech.discardRecording() }
            }
            .onChange(of: speech.transcript) { _, transcript in
                guard usedVoice else { return }
                text = joined(textBeforeVoice, transcript)
            }
            .onChange(of: speech.lastError) { _, message in
                if let message { errorText = message }
            }
            .interactiveDismissDisabled(speech.isRecording)
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Voice

    private var voiceButton: some View {
        Button {
            if speech.isRecording { stopVoice() } else { Task { await startVoice() } }
        } label: {
            Label(speech.isRecording ? "Stop" : "Speak",
                  systemImage: speech.isRecording ? "stop.fill" : "mic.fill")
                .font(.body.weight(.semibold))
                .padding(.horizontal, ForgeSpacing.l)
                .padding(.vertical, ForgeSpacing.s + 4)
                .foregroundStyle(.white)
                .background(ForgeColor.ember, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!speech.isAvailable && !speech.isRecording)
        .opacity(speech.isAvailable || speech.isRecording ? 1 : 0.4)
        .accessibilityLabel(speech.isRecording ? "Stop recording" : "Speak your idea")
    }

    private var listeningRow: some View {
        HStack(spacing: ForgeSpacing.s) {
            Circle()
                .fill(ForgeColor.ember)
                .frame(width: 10, height: 10)
                .scaleEffect(1 + CGFloat(speech.level) * 1.4)
                .forgeAnimation(ForgeMotion.fade, value: speech.level)
                .accessibilityHidden(true)
            Text("Speak naturally. Tap Stop when you're done, then fix anything it misheard.")
                .font(.caption)
                .foregroundStyle(ForgeColor.inkSecondary)
        }
        .padding(.horizontal, ForgeSpacing.xs)
    }

    private func startVoice() async {
        errorText = nil
        focused = false
        if !speech.isAuthorized {
            let ok = await speech.requestAuthorization()
            guard ok else { errorText = speech.lastError; return }
        }
        guard speech.isAvailable else {
            errorText = CaptureError.recognizerUnavailable.errorDescription
            return
        }
        textBeforeVoice = text
        usedVoice = true
        do {
            try speech.start()
        } catch {
            errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func stopVoice() {
        speech.stop()
        focused = true
    }

    // MARK: Text helpers

    private func append(_ addition: String) {
        text = joined(text, addition)
    }

    private func joined(_ a: String, _ b: String) -> String {
        let left = a.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = b.trimmingCharacters(in: .whitespacesAndNewlines)
        if left.isEmpty { return right }
        if right.isEmpty { return left }
        return left + "\n" + right
    }

    // MARK: Actions

    private func save() {
        guard canSave else { return }
        let audio = usedVoice ? speech.recordingURL?.lastPathComponent : nil
        let idea = Idea(originalText: text, audioFileName: audio)
        context.insert(idea)
        saved = true
        speech.reset()
        dismiss()
    }

    private func cancel() {
        speech.discardRecording()
        dismiss()
    }
}

#Preview {
    CaptureSheet()
        .environment(AppEnvironment.live)
        .modelContainer(try! .forge(inMemory: true))
}
