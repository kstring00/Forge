import SwiftUI
import SwiftData
import ForgeCore

/// §5, closing the loop: after the user records what happened on an idea, each
/// ruling it might settle is listed, disagreements and find-outs first, with
/// three answers: the Sphere was right, you were right, not settled. The
/// outcome is stored on the Ruling and read back as one line ("You disagreed
/// with the Strategist. It was right.").
struct SettleRulingsSheet: View {
    let idea: Idea
    let whatHappened: String
    @Environment(\.dismiss) private var dismiss
    @State private var choices: [UUID: RulingOutcome] = [:]

    private var rulings: [Ruling] { RulingActions.unsettled(on: idea) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("What happened").forgeLabel()
                        Text(whatHappened).font(ForgeType.originalText).foregroundStyle(ForgeColor.ink)
                    }
                    Text("Does this settle any of the panel's points? Pick only what it settles; the rest can wait.")
                        .font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary)
                    ForEach(rulings) { ruling in
                        if let v = ruling.verdict { row(ruling, v) }
                    }
                }
                .padding(ForgeSpacing.m)
                .padding(.bottom, ForgeSpacing.xxl)
            }
            .background(ForgeColor.canvas)
            .navigationTitle("Settle the panel")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Later") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }.fontWeight(.semibold).disabled(choices.isEmpty)
                }
            }
        }
        .presentationDetents([.large])
    }

    private func row(_ ruling: Ruling, _ v: Verdict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                OrbView(sphere: v.sphere, state: .verdict(v.kind), size: 24)
                Text("\(v.sphere.displayName) · \(v.kind.displayName)").font(.system(size: 14, weight: .semibold)).foregroundStyle(ForgeColor.ink)
                Spacer()
                Text(ruling.implicit ? "You let it stand" : "You: \(ruling.choice.displayName)").forgeLabelSmall()
            }
            Text(v.reason).font(.system(size: 13)).foregroundStyle(ForgeColor.inkSecondary).lineLimit(3)
            HStack(spacing: 8) {
                ForEach(RulingOutcome.allCases, id: \.self) { o in
                    let on = choices[ruling.id] == o
                    Button { choices[ruling.id] = on ? nil : o } label: {
                        Text(o.displayName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(on ? .white : ForgeColor.ink)
                            .padding(.horizontal, 12).frame(height: 32)
                            .background(on ? ForgeColor.ember : ForgeColor.canvas, in: Capsule())
                            .overlay(Capsule().strokeBorder(on ? Color.clear : ForgeColor.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: ForgeSpacing.cardRadius, style: .continuous).strokeBorder(ForgeColor.line))
    }

    private func save() {
        for ruling in rulings {
            if let o = choices[ruling.id] { RulingActions.recordOutcome(o, note: whatHappened, on: ruling) }
        }
    }
}
