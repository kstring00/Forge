import SwiftUI
import SwiftData

/// "Make it real": one next step, what launched means, and the Journal's
/// commit entry: what you believe, why, what you expect and by when.
struct ConvertToProjectSheet: View {
    let idea: Idea
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var desiredOutcome = ""
    @State private var nextStep = ""
    @State private var beliefs = ""
    @State private var reasoning = ""
    @State private var expectedResult = ""
    @State private var hasDeadline = false
    @State private var expectedBy = Calendar.current.date(byAdding: .day, value: 14, to: .now) ?? .now

    init(idea: Idea) {
        self.idea = idea
        _name = State(initialValue: idea.title)
    }

    private var canCommit: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !nextStep.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    field("Project name", text: $name, prompt: "Short and plain")
                    field("What does launched mean for this?", text: $desiredOutcome,
                          prompt: "First paying customer, finished chapter, shared prototype…", lines: 3)
                    field("The one next step", text: $nextStep,
                          prompt: "Something you can do this week. One action.", lines: 2)

                    VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                        Text("For the Journal").forgeLabel()
                        Text("Later, FORGE will ask what actually happened and put it next to this.")
                            .font(.footnote)
                            .foregroundStyle(ForgeColor.inkSecondary)
                    }
                    field("What do you believe that makes this worth doing?", text: $beliefs, prompt: "The belief, not the pitch.", lines: 3)
                    field("Why now?", text: $reasoning, prompt: "Optional.", lines: 2)
                    field("What result do you expect?", text: $expectedResult, prompt: "Something you could check.", lines: 2)
                    Toggle("By a date", isOn: $hasDeadline)
                    if hasDeadline {
                        DatePicker("Expected by", selection: $expectedBy, in: Date.now..., displayedComponents: .date)
                    }
                }
                .padding(ForgeSpacing.m)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(ForgeColor.canvas)
            .navigationTitle("Make it real")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Commit") { commit() }
                        .disabled(!canCommit)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    private func commit() {
        let c = WorkshopActions.Commitment(
            name: name, desiredOutcome: desiredOutcome, nextStep: nextStep,
            beliefs: beliefs, reasoning: reasoning, expectedResult: expectedResult,
            expectedBy: hasDeadline ? expectedBy : nil)
        WorkshopActions.convert(idea, with: c, in: context)
        dismiss()
    }

    private func field(_ label: String, text: Binding<String>, prompt: String, lines: Int = 1) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
            Text(label).forgeLabel()
            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(lines...max(lines, 6))
                .font(ForgeType.body)
                .padding(ForgeSpacing.m)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                .accessibilityLabel(label)
        }
    }
}
