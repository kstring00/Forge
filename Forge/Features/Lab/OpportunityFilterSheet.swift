import SwiftUI
import ForgeCore

/// §4.1 Opportunity Filter: ten yes / no / unsure in sixty seconds. Not scored;
/// three or more "no" suggests exploring or revisiting before a full evaluation.
struct OpportunityFilterSheet: View {
    let idea: Idea
    var onContinue: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var answers: [String: TriageAnswer]

    init(idea: Idea, onContinue: @escaping () -> Void) {
        self.idea = idea
        self.onContinue = onContinue
        _answers = State(initialValue: idea.triage?.answers ?? [:])
    }

    private var verdict: TriageVerdict { Triage.evaluate(answers) }
    private var allAnswered: Bool { answers.count == OpportunityFilterQuestions.all.count }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                    Text("Opportunity filter").forgeLabel()
                    Text("Sixty seconds. Gut answers are fine; the point is to notice red flags before you invest an hour.")
                        .font(ForgeType.secondary)
                        .foregroundStyle(ForgeColor.inkSecondary)

                    ForEach(OpportunityFilterQuestions.all) { q in
                        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
                            Text(q.text)
                                .font(ForgeType.body)
                                .foregroundStyle(ForgeColor.ink)
                            Picker(q.text, selection: Binding(
                                get: { answers[q.key] },
                                set: { answers[q.key] = $0 }
                            )) {
                                Text("Yes").tag(TriageAnswer?.some(.yes))
                                Text("No").tag(TriageAnswer?.some(.no))
                                Text("Unsure").tag(TriageAnswer?.some(.unsure))
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                        }
                        .padding(ForgeSpacing.m)
                        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                    }

                    if answers.count > 0 {
                        verdictCard
                    }
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xxl)
            }
            .background(ForgeColor.canvas)
            .navigationTitle("Screen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(verdict.flagged ? "Score anyway" : "Score it") {
                        save()
                        onContinue()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!allAnswered)
                }
            }
        }
    }

    private var verdictCard: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack {
                Text("\(verdict.noCount) no · \(verdict.unsureCount) unsure").forgeLabel()
                Spacer()
                if verdict.flagged, let s = verdict.suggestion {
                    Text(s.displayName).forgeLabel().foregroundStyle(ForgeColor.emberText)
                }
            }
            Text(verdict.flagged
                 ? "Three or more no. FORGE suggests \(verdict.suggestion?.displayName.lowercased() ?? "exploring further") before a full evaluation. You can still score it; the suggestion will be remembered."
                 : "No red flags so far. Scoring will take ten to fifteen minutes if you read the rubrics.")
                .font(.caption)
                .foregroundStyle(ForgeColor.inkSecondary)
            if verdict.flagged {
                Button("Save and explore further") {
                    save()
                    dismiss()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(ForgeColor.ink)
            }
        }
        .padding(ForgeSpacing.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(verdict.flagged ? ForgeColor.ember.opacity(0.6) : ForgeColor.line))
    }

    private func save() {
        let triage = idea.triage ?? OpportunityFilter()
        for (k, v) in answers { triage.answer(k, v) }
        if idea.triage == nil { idea.triage = triage }
        idea.touch()
    }
}
