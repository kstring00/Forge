import SwiftUI

/// Shown once, before the first AI call. Plain words, a real choice.
struct AIConsentSheet: View {
    var onDecision: (Bool) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ForgeSpacing.l) {
                    Text("Before FORGE talks to an AI")
                        .font(ForgeType.ideaTitle)
                        .foregroundStyle(ForgeColor.ink)
                    Text("When you tap an AI action, FORGE sends parts of this idea to an AI provider through your own proxy. Nothing is sent until you agree, and nothing is ever sent for ideas you don't ask about.")
                        .font(ForgeType.body)
                        .foregroundStyle(ForgeColor.ink)

                    list("What is sent", AIConsent.whatIsSent)
                    list("Never sent", AIConsent.neverSent)

                    VStack(alignment: .leading, spacing: ForgeSpacing.xs) {
                        Text("Through").forgeLabel()
                        Text(AIConsent.proxyURL ?? "No proxy is configured yet. AI actions show as offline until one is.")
                            .font(ForgeType.secondary)
                            .foregroundStyle(ForgeColor.ink)
                    }

                    Text("You can withdraw this at any time in Settings, where the same list is shown.")
                        .font(.caption)
                        .foregroundStyle(ForgeColor.inkSecondary)
                }
                .padding(ForgeSpacing.m)
            }
            .background(ForgeColor.canvas)
            .navigationTitle("AI sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Not now") { onDecision(false) }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Agree and continue") { onDecision(true) }
                        .fontWeight(.semibold)
                }
            }
        }
        .interactiveDismissDisabled()
    }

    private func list(_ title: String, _ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            Text(title).forgeLabel()
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: ForgeSpacing.s) {
                    Text("•").foregroundStyle(ForgeColor.inkSecondary)
                    Text(item).font(ForgeType.secondary).foregroundStyle(ForgeColor.ink)
                }
            }
        }
    }
}
