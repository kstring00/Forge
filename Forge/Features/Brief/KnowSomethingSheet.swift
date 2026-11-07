import SwiftUI
import SwiftData
import ForgeCore

/// "I know something you don't." What the user says becomes a user-verified
/// Source; the Spheres re-score only the criteria that cite it, in a new
/// evaluation version that keeps everything else.
struct KnowSomethingSheet: View {
    let idea: Idea
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env
    @State private var text = ""
    @State private var running = false
    @State private var message: String?
    @FocusState private var focused: Bool

    private var canSave: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !running }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                Text("What do you know that the desk can't?").font(ForgeType.ideaTitle).foregroundStyle(ForgeColor.ink)
                Text("Something you saw, heard or did. A conversation, a payment, a number from your own work. It is saved as verified by you and the Spheres re-score only what it touches.")
                    .font(ForgeType.secondary).foregroundStyle(ForgeColor.inkSecondary)
                TextEditor(text: $text)
                    .font(ForgeType.body)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 140)
                    .padding(ForgeSpacing.s)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                    .focused($focused)
                    .disabled(running)
                if running {
                    HStack(spacing: ForgeSpacing.s) { ProgressView().controlSize(.small); Text("Re-scoring what this touches…").font(.caption).foregroundStyle(ForgeColor.inkSecondary) }
                }
                if let message { Text(message).font(.caption).foregroundStyle(ForgeColor.inkSecondary) }
                Spacer()
            }
            .padding(ForgeSpacing.m)
            .background(ForgeColor.canvas)
            .navigationTitle("I know something")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(running) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save and re-score") { Task { await save() } }.disabled(!canSave).fontWeight(.semibold)
                }
            }
            .onAppear { focused = true }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(running)
    }

    private func save() async {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = Source(kind: .note, title: String(body.prefix(60)), fullText: body, sourceClass: .userVerified)
        source.reviewed = true
        source.chunks.append(SourceChunk(index: 0, text: body))
        idea.sources.append(source)
        try? context.save()

        guard let previous = idea.latestEvaluation else { dismiss(); return }
        running = true
        defer { running = false }
        do {
            let envelope = try await env.ai.perform(.prefill, context: AIContext.make(for: idea), expecting: PrefillResult.self)
            if let cost = envelope.costUSD { AISpend.record(cost) }
            let touched = envelope.payload.criteria.filter { $0.sourceIDs.contains(source.id) }
            guard !touched.isEmpty else {
                message = "Saved as verified. The panel did not find a criterion it changes; you can attach it yourself in the Lab."
                return
            }
            let next = idea.beginEvaluation(lens: previous.lensType, copying: previous)
            for c in touched {
                try? next.set(key: c.key, score: c.score, evidenceLevel: c.evidenceLevel, note: c.note)
                next.criterionScore(for: c.key)?.aiProposed = true
                next.criterionScore(for: c.key)?.evidence.append(Evidence(criterionKey: c.key, ladderRung: c.evidenceLevel, text: body, source: source))
            }
            next.recompute()
            next.aiFilledAt = Date()
            try? context.save()
            dismiss()
        } catch let error as AIError {
            message = error == .offline || error == .notConfigured
                ? "Saved as verified. The re-score needs the proxy; attach it to a criterion in the Lab for now."
                : "Saved as verified. The re-score failed: \(error)."
        } catch {
            message = "Saved as verified. The re-score failed: \(error.localizedDescription)"
        }
    }
}
