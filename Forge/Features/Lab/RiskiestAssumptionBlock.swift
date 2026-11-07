import SwiftUI

/// The single belief that, if wrong, kills the idea. The user's words.
struct RiskiestAssumptionBlock: View {
    @Bindable var evaluation: Evaluation
    @State private var editing = false

    var body: some View {
        Button { editing = true } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text("Riskiest assumption").forgeLabel()
                if evaluation.riskiestAssumption.isEmpty {
                    Text("Tap to name the one belief that, if wrong, kills this.")
                        .font(ForgeType.statement)
                        .foregroundStyle(ForgeColor.inkSecondary)
                } else {
                    Text(evaluation.riskiestAssumption)
                        .font(ForgeType.statement)
                        .foregroundStyle(ForgeColor.ink)
                    if let why = evaluation.riskiestAssumptionConsequence, !why.isEmpty {
                        Text(why)
                            .font(.system(size: 12))
                            .foregroundStyle(ForgeColor.inkSecondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(evaluation.isFinal)
        .sheet(isPresented: $editing) { RiskiestAssumptionSheet(evaluation: evaluation) }
    }
}

struct RiskiestAssumptionSheet: View {
    @Bindable var evaluation: Evaluation
    @Environment(\.dismiss) private var dismiss
    @State private var belief = ""
    @State private var consequence = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: ForgeSpacing.m) {
                Text("The one belief that, if wrong, kills it").forgeLabel()
                TextField("That a park owner will pay monthly for a site they don't check…", text: $belief, axis: .vertical)
                    .lineLimit(2...5)
                    .font(ForgeType.statement)
                    .padding(ForgeSpacing.m)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                Text("If wrong").forgeLabel()
                TextField("What happens to the idea if this turns out false?", text: $consequence, axis: .vertical)
                    .lineLimit(1...4)
                    .font(ForgeType.body)
                    .padding(ForgeSpacing.m)
                    .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.controlRadius, style: .continuous).strokeBorder(ForgeColor.line))
                Text("Lean Startup: the riskiest assumption is the one to test first, because it is the cheapest way to find out you are wrong.")
                    .font(.caption)
                    .foregroundStyle(ForgeColor.inkSecondary)
                Spacer()
            }
            .padding(ForgeSpacing.m)
            .background(ForgeColor.canvas)
            .navigationTitle("Riskiest assumption")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        evaluation.riskiestAssumption = belief.trimmingCharacters(in: .whitespacesAndNewlines)
                        let c = consequence.trimmingCharacters(in: .whitespacesAndNewlines)
                        evaluation.riskiestAssumptionConsequence = c.isEmpty ? nil : c
                        evaluation.idea?.touch()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                belief = evaluation.riskiestAssumption
                consequence = evaluation.riskiestAssumptionConsequence ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }
}
