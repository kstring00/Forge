import SwiftUI

/// Calm, one-sentence empty state with an optional single action.
struct EmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: ForgeSpacing.m) {
            Image(systemName: symbol)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(ForgeColor.inkSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(ForgeType.ideaTitle)
                .foregroundStyle(ForgeColor.ink)
                .multilineTextAlignment(.center)
            Text(message)
                .font(ForgeType.secondary)
                .foregroundStyle(ForgeColor.inkSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            if let actionTitle, let action {
                EmberButton(title: actionTitle, symbol: nil, action: action)
                    .padding(.top, ForgeSpacing.s)
            }
        }
        .padding(ForgeSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    EmptyState(symbol: "archivebox", title: "Nothing in the Vault yet",
               message: "Capture a thought and it lands here.", actionTitle: "Capture") {}
        .background(ForgeColor.canvas)
}
