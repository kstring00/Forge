import SwiftUI
import SwiftData
import ForgeCore

/// The ember button: "Next move · Test it" over one concrete step. Advisory;
/// the user picks the move and writes the step. Tapping opens the chooser.
struct NextMoveButton: View {
    @Bindable var evaluation: Evaluation
    @State private var choosing = false

    var body: some View {
        Button { choosing = true } label: {
            HStack(alignment: .center, spacing: ForgeSpacing.m) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Next move · \(NextMove.shortLabel(evaluation.effectiveMove))")
                        .font(ForgeType.label)
                        .textCase(.uppercase)
                        .kerning(1.3)
                        .foregroundStyle(Color(red: 1.0, green: 0.886, blue: 0.839))
                    Text(evaluation.effectiveStep)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(.white)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.ember, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Next move: \(evaluation.effectiveMove.displayName). \(evaluation.effectiveStep)")
        .sheet(isPresented: $choosing) { NextMoveSheet(evaluation: evaluation) }
    }
}

/// Pick the move (the suggestion is marked), write the step, and for "Test it"
/// fill the Experiment card: hypothesis, test, metric, cost, timebox, decision rule.
struct NextMoveSheet: View {
    @Bindable var evaluation: Evaluation
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var move: Recommendation = .exploreFurther
    @State private var step = ""
    @State private var hypothesis = ""
    @State private var test = ""
    @State private var metric = ""
    @State private var cost = ""
    @State private var timebox = 7
    @State private var decisionRule = ""

    private var suggested: Recommendation { evaluation.suggestedMove(triageFlagged: evaluation.idea?.triage?.verdict.flagged ?? false) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(Recommendation.allCases, id: \.self) { r in
                        Button {
                            move = r
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(r.displayName).foregroundStyle(ForgeColor.ink)
                                    if r == suggested {
                                        Text("Suggested from your scores").font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                                    }
                                }
                                Spacer()
                                if r == move { Image(systemName: "checkmark").foregroundStyle(ForgeColor.ink) }
                            }
                        }
                    }
                } header: {
                    Text("Move")
                } footer: {
                    Text("Advisory. The suggestion comes from Potential and Confidence; you decide.")
                }

                Section("The concrete step") {
                    TextField(NextMove.defaultStep(move, lens: evaluation.lens, lowestKey: evaluation.lowestKey), text: $step, axis: .vertical)
                        .lineLimit(1...4)
                }

                if move == .testRiskiestAssumption {
                    Section {
                        TextField("Hypothesis", text: $hypothesis, axis: .vertical)
                        TextField("Test", text: $test, axis: .vertical)
                        TextField("Metric", text: $metric, axis: .vertical)
                        TextField("Cost", text: $cost)
                        Stepper("Timebox: \(timebox) days", value: $timebox, in: 1...60)
                        TextField("Decision rule (what result means stop, what means go)", text: $decisionRule, axis: .vertical)
                    } header: {
                        Text("Experiment card")
                    } footer: {
                        Text("The cheapest test of the riskiest assumption. Hypothesis · Test · Metric · Cost · Timebox · Decision rule.")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ForgeColor.canvas)
            .navigationTitle("Next move")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        move = evaluation.recommendation ?? suggested
        step = evaluation.nextStepText ?? ""
        if let x = evaluation.experiment {
            hypothesis = x.hypothesis; test = x.test; metric = x.metric; cost = x.cost
            timebox = x.timeboxDays; decisionRule = x.decisionRule
        } else {
            hypothesis = evaluation.riskiestAssumption
        }
    }

    private func save() {
        evaluation.recommendation = move
        let s = step.trimmingCharacters(in: .whitespacesAndNewlines)
        evaluation.nextStepText = s.isEmpty ? nil : s
        if move == .testRiskiestAssumption {
            let filled = ![hypothesis, test, metric, decisionRule].allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
            if filled {
                if let x = evaluation.experiment {
                    x.hypothesis = hypothesis; x.test = test; x.metric = metric; x.cost = cost
                    x.timeboxDays = timebox; x.decisionRule = decisionRule
                } else {
                    evaluation.experiment = Experiment(hypothesis: hypothesis, test: test, metric: metric, cost: cost,
                                                       timeboxDays: timebox, decisionRule: decisionRule)
                }
            }
        }
        evaluation.idea?.touch()
    }
}
