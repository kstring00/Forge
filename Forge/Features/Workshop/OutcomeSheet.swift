import SwiftUI
import ForgeCore

/// The one question the Journal asks: "What actually happened?" Typed or
/// spoken. The answer is saved as a user-verified Source; when it shows a
/// person gave time, money or came back, the user confirms the rung and the
/// ladder moves (§0A step 6).
struct OutcomeSheet: View {
    let title: String
    let subject: String
    var prompt = "What actually happened?"
    var footnote = "Stored next to what you expected, and saved as verified by you."
    var showsNextStep = false
    /// Offer the ladder rung. Off for notes that prove nothing (pausing).
    var asksRung = true
    /// A logged conversation starts at rung 3: the person gave their time.
    var minimumRung = 0
    var onSave: (FieldEvidence.Report, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @State private var whatHappened = ""
    @State private var nextStep = ""
    @State private var rung: Int?
    @State private var touchedRung = false
    @FocusState private var focused: Bool

    private var speech: SpeechCapture { env.speech }
    private var canSave: Bool { !speech.isRecording && !whatHappened.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var guess: RungInference.Guess? { RungInference.infer(whatHappened) }
    private var effectiveRung: Int { max(minimumRung, rung ?? guess?.rung ?? 0) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                    Text(subject)
                        .font(ForgeType.ideaTitle)
                        .foregroundStyle(ForgeColor.ink)
                    VoiceNoteField(label: prompt, text: $whatHappened, focused: $focused, minHeight: 120)
                    if asksRung { rungPicker }
                    if showsNextStep {
                        Text("And the one next thing").forgeSubhead()
                        TextField("Leave empty to decide later", text: $nextStep, axis: .vertical)
                            .lineLimit(1...4)
                            .font(ForgeType.body)
                            .padding(ForgeSpacing.m)
                            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                            .accessibilityLabel("Next step")
                    }
                    Text(footnote)
                        .font(.footnote)
                        .foregroundStyle(ForgeColor.inkSecondary)
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xl)
            }
            .background(ForgeColor.canvas)
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { speech.discardRecording(); dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let audio = speech.recordingURL?.lastPathComponent
                        speech.reset()
                        onSave(FieldEvidence.Report(text: whatHappened, rung: asksRung ? effectiveRung : 0, audioFileName: audio), showsNextStep ? nextStep : nil)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
            .onDisappear { if speech.isRecording { speech.discardRecording() } }
            .interactiveDismissDisabled(speech.isRecording)
        }
        .presentationDetents([.medium, .large])
    }

    /// Time · Money · Came back · Nothing yet. Preselected from the words; the user confirms.
    private var rungPicker: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack {
                Text("What did they give?").forgeSubhead()
                Spacer()
                if !touchedRung, let guess, rung == nil {
                    Text("Sounds like \(guess.because)").font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { r in
                    let on = effectiveRung == r
                    Button { rung = r; touchedRung = true } label: {
                        Text(RungInference.label(r))
                            .font(.system(.footnote, weight: .medium))
                            .foregroundStyle(on ? .white : ForgeColor.ink)
                            .padding(.horizontal, 12).frame(height: 32)
                            .background(on ? ForgeColor.ember : ForgeColor.surface, in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? Color.clear : ForgeColor.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            Text(effectiveRung >= 3
                 ? "\(Plain.rung(effectiveRung).prefix(1).uppercased() + Plain.rung(effectiveRung).dropFirst()) (rung \(effectiveRung)). Verified by you, so Confidence, how sure we are, can rise past what the desk could prove."
                 : "Saved as verified. Nothing claimed on the ladder until a real person gives time, money, or comes back.")
                .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
        }
    }

    private var options: [Int] { minimumRung >= 3 ? [3, 4, 5] : [0, 3, 4, 5] }
}

/// A text field that also listens. Speak appends the live transcript; the
/// recording stays on the device and travels with the Source as its file.
struct VoiceNoteField: View {
    let label: String
    @Binding var text: String
    var focused: FocusState<Bool>.Binding
    var minHeight: CGFloat = 120

    @Environment(AppEnvironment.self) private var env
    @State private var textBeforeVoice = ""
    @State private var usedVoice = false
    @State private var errorText: String?

    private var speech: SpeechCapture { env.speech }

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack {
                Text(speech.isRecording ? "Listening" : label).forgeLabel()
                Spacer()
                Button {
                    if speech.isRecording { speech.stop(); focused.wrappedValue = true } else { Task { await start() } }
                } label: {
                    Label(speech.isRecording ? "Stop" : "Speak", systemImage: speech.isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(.footnote, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12).frame(height: 30)
                        .background(ForgeColor.ember, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!speech.isAvailable && !speech.isRecording)
                .opacity(speech.isAvailable || speech.isRecording ? 1 : 0.4)
                .accessibilityLabel(speech.isRecording ? "Stop recording" : "Speak instead of typing")
            }
            TextEditor(text: $text)
                .font(ForgeType.body)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(ForgeSpacing.s)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous)
                    .strokeBorder(speech.isRecording ? ForgeColor.ember.opacity(0.6) : ForgeColor.line))
                .disabled(speech.isRecording)
                .focused(focused)
                .accessibilityLabel(label)
            if speech.isRecording {
                HStack(spacing: ForgeSpacing.s) {
                    Circle().fill(ForgeColor.ember).frame(width: 10, height: 10)
                        .scaleEffect(1 + CGFloat(speech.level) * 1.4)
                        .forgeAnimation(ForgeMotion.fade, value: speech.level)
                        .accessibilityHidden(true)
                    Text("Speak naturally. Tap Stop when you're done, then fix anything it misheard.")
                        .font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
                }
            }
            if let errorText {
                Text(errorText).font(.footnote).foregroundStyle(ForgeColor.inkSecondary)
            }
        }
        .onChange(of: speech.transcript) { _, transcript in
            guard usedVoice else { return }
            let left = textBeforeVoice.trimmingCharacters(in: .whitespacesAndNewlines)
            let right = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            text = left.isEmpty ? right : (right.isEmpty ? left : left + "\n" + right)
        }
        .onChange(of: speech.lastError) { _, message in
            if let message { errorText = message }
        }
    }

    private func start() async {
        errorText = nil
        focused.wrappedValue = false
        if !speech.isAuthorized {
            let ok = await speech.requestAuthorization()
            guard ok else { errorText = speech.lastError; return }
        }
        guard speech.isAvailable else { errorText = CaptureError.recognizerUnavailable.errorDescription; return }
        textBeforeVoice = text
        usedVoice = true
        do { try speech.start() } catch { errorText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription }
    }
}
