import SwiftUI
import ForgeCore

/// §4.0. Business lens: three figures the user typed, and a bar that is solid
/// only for units a real payment backs. Other lenses: Impact, no dollar figures.
struct ProjectionCard: View {
    @Bindable var evaluation: Evaluation
    @State private var editing = false

    var body: some View {
        Button { editing = true } label: {
            VStack(alignment: .leading, spacing: 12) {
                if evaluation.lensType == .business { projection } else { impact }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
        }
        .buttonStyle(.plain)
        .disabled(evaluation.isFinal)
        .sheet(isPresented: $editing) { ProjectionEditSheet(evaluation: evaluation) }
    }

    // MARK: Projection (Business)

    @ViewBuilder
    private var projection: some View {
        let p = evaluation.projection
        HStack {
            Text("Projection · If it works").forgeLabel()
            Spacer()
            HStack(spacing: 6) {
                EvidenceChip(pattern: .dots, size: 12)
                Text("Estimate").forgeLabelSmall()
            }
        }
        HStack(alignment: .top, spacing: 10) {
            figure(p.pricePerUnit.map { Projection.compact($0) } ?? "—", "per unit / mo")
            figure(p.unitsYearOne.map(String.init) ?? "—", "units, year one")
            figure(p.recurringPerMonth.map { Projection.compact($0) } ?? "—", "recurring / mo", tint: ForgeColor.emberText)
        }
        bar(verified: p.verifiedFraction)
        HStack {
            Text("\(p.verifiedUnits) paying today").forgeLabelSmall()
            Spacer()
            Text("\(p.assumedUnits) assumed").forgeLabelSmall()
        }
        note(p.isEmpty
             ? "Tap to enter a price and a count. Every figure stays yours, drawn as an assumption until a real payment is attached as evidence at rung 4."
             : "Every figure here is yours until someone pays for month two. A slice goes solid only when a real payment is attached as evidence at rung 4 or above.")
    }

    // MARK: Impact (Growth, Creative)

    @ViewBuilder
    private var impact: some View {
        HStack {
            Text("Impact").forgeLabel()
            Spacer()
            HStack(spacing: 6) {
                EvidenceChip(pattern: .dots, size: 12)
                Text("Hoped for").forgeLabelSmall()
            }
        }
        impactLine("Who this helps", evaluation.impactWho)
        impactLine("What changes for them", evaluation.impactWhatChanges)
        impactLine("How you'd know", evaluation.impactSignal)
        let observed = evaluation.allEvidence.contains { $0.ladderRung >= 3 && $0.countsTowardConfidence }
        bar(verified: observed ? 1 : 0)
        note("No dollar figures on this lens. The bar goes solid when you have observed the signal, not when you hope for it.")
    }

    private func impactLine(_ label: String, _ value: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).forgeLabelSmall()
            Text((value ?? "").isEmpty ? "—" : value!)
                .font(ForgeType.body)
                .foregroundStyle(ForgeColor.ink)
        }
    }

    // MARK: Pieces

    private func figure(_ value: String, _ label: String, tint: Color = ForgeColor.ink) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(ForgeType.numeralMedium)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).forgeLabelSmall()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func bar(verified: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(ForgeColor.line)
                HStack(spacing: 0) {
                    Rectangle().fill(ForgeColor.ink).frame(width: geo.size.width * verified)
                    EvidenceFill(pattern: .stripes, color: ForgeColor.inkSecondary)
                }
                .clipShape(RoundedRectangle(cornerRadius: 3))
            }
        }
        .frame(height: 6)
        .accessibilityLabel("\(Int((verified * 100).rounded())) percent verified")
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 13))
            .foregroundStyle(ForgeColor.ink.opacity(0.85))
            .padding(.top, 8)
            .overlay(alignment: .top) { Rectangle().fill(ForgeColor.line).frame(height: 1) }
    }
}

struct ProjectionEditSheet: View {
    @Bindable var evaluation: Evaluation
    @Environment(\.dismiss) private var dismiss
    @State private var price: String = ""
    @State private var units: String = ""
    @State private var who = ""
    @State private var changes = ""
    @State private var signal = ""

    var body: some View {
        NavigationStack {
            Form {
                if evaluation.lensType == .business {
                    Section {
                        TextField("Price per unit per month", text: $price).keyboardType(.decimalPad)
                        TextField("Units in year one", text: $units).keyboardType(.numberPad)
                        if let p = Double(price), let u = Int(units), p > 0, u > 0 {
                            LabeledContent("Recurring per month", value: Projection.compact(p * Double(u)))
                        }
                    } header: {
                        Text("Projection")
                    } footer: {
                        Text("Your numbers, drawn as assumptions. The AI may later suggest a range, labeled as an estimate; you accept or edit it.")
                    }
                } else {
                    Section("Impact") {
                        TextField("Who this helps", text: $who, axis: .vertical)
                        TextField("What changes for them", text: $changes, axis: .vertical)
                        TextField("How you'd know (an observable signal)", text: $signal, axis: .vertical)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(ForgeColor.canvas)
            .navigationTitle(evaluation.lensType == .business ? "Projection" : "Impact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }.fontWeight(.semibold)
                }
            }
            .onAppear {
                price = evaluation.projectionPricePerUnit.map { $0 == $0.rounded() ? String(Int($0)) : String($0) } ?? ""
                units = evaluation.projectionUnitsYearOne.map(String.init) ?? ""
                who = evaluation.impactWho ?? ""
                changes = evaluation.impactWhatChanges ?? ""
                signal = evaluation.impactSignal ?? ""
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func save() {
        if evaluation.lensType == .business {
            evaluation.projectionPricePerUnit = Double(price.replacingOccurrences(of: ",", with: "."))
            evaluation.projectionUnitsYearOne = Int(units)
            evaluation.projectionRecurringPerMonth = evaluation.projection.recurringPerMonth
        } else {
            evaluation.impactWho = who.isEmpty ? nil : who
            evaluation.impactWhatChanges = changes.isEmpty ? nil : changes
            evaluation.impactSignal = signal.isEmpty ? nil : signal
        }
        evaluation.idea?.touch()
    }
}
