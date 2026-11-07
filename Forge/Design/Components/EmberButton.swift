import SwiftUI

/// The one accent control. Used for capture and "next step", nowhere else.
struct EmberButton: View {
    let title: String
    var symbol: String? = nil
    var isFloating = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ForgeSpacing.s) {
                if let symbol { Image(systemName: symbol).font(.body.weight(.semibold)) }
                Text(title).font(.body.weight(.semibold))
            }
            .padding(.horizontal, isFloating ? ForgeSpacing.l : ForgeSpacing.l)
            .padding(.vertical, isFloating ? ForgeSpacing.m : ForgeSpacing.s + 4)
            .foregroundStyle(.white)
            .background(ForgeColor.ember, in: Capsule())
            .shadow(color: isFloating ? ForgeColor.ember.opacity(0.35) : .clear, radius: 14, y: 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    static func floating(title: String, symbol: String, action: @escaping () -> Void) -> EmberButton {
        EmberButton(title: title, symbol: symbol, isFloating: true, action: action)
    }
}
