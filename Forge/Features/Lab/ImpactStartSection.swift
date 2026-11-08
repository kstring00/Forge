import SwiftUI
import ForgeCore

/// §4.0 for Growth and Creative ideas before anything is written: the Impact
/// card in place of the Reality Check, which researches markets and belongs to
/// the Business lens. Saving the three answers starts the idea's first
/// evaluation in its own lens; nothing is created by just looking.
struct ImpactStartSection: View {
    @Bindable var idea: Idea
    let lens: LensType
    @State private var editing = false

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.m) {
            Button { editing = true } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Impact").forgeLabel()
                        Spacer()
                        HStack(spacing: 6) {
                            EvidenceChip(pattern: .dots, size: 12)
                            Text("Hoped for").forgeLabelSmall()
                        }
                    }
                    line("Who this helps")
                    line("What changes for them")
                    line("How you'd know")
                    Text("Tap to answer the three. No dollar figures on this lens; the bar goes solid when you have observed the signal, not when you hope for it.")
                        .font(.system(.footnote))
                        .foregroundStyle(ForgeColor.ink.opacity(0.85))
                        .padding(.top, 8)
                        .overlay(alignment: .top) { Rectangle().fill(ForgeColor.line).frame(height: 1) }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Impact. Who this helps, what changes for them, how you'd know.")

            Text(RealityCheckPolicy.notOfferedLine)
                .font(.footnote)
                .foregroundStyle(ForgeColor.inkSecondary)
        }
        .sheet(isPresented: $editing) { ImpactStartSheet(idea: idea, lens: lens) }
    }

    private func line(_ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).forgeLabelSmall()
            Text("—").font(ForgeType.body).foregroundStyle(ForgeColor.inkSecondary)
        }
    }
}

/// The three Impact answers. Save starts the evaluation in the idea's lens.
private struct ImpactStartSheet: View {
    let idea: Idea
    let lens: LensType
    @Environment(\.dismiss) private var dismiss
    @State private var who = ""
    @State private var changes = ""
    @State private var signal = ""

    private var isEmpty: Bool {
        [who, changes, signal].allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Who this helps", text: $who, axis: .vertical)
                    TextField("What changes for them", text: $changes, axis: .vertical)
                    TextField("How you'd know (an observable signal)", text: $signal, axis: .vertical)
                } footer: {
                    Text("Your words, drawn as hoped-for until you observe the signal.")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ForgeColor.canvas)
            .navigationTitle("Impact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                        .fontWeight(.semibold)
                        .disabled(isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        let e = idea.beginEvaluation(lens: lens)
        let t = { (s: String) -> String? in
            let v = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return v.isEmpty ? nil : v
        }
        e.impactWho = t(who)
        e.impactWhatChanges = t(changes)
        e.impactSignal = t(signal)
        idea.touch()
    }
}
