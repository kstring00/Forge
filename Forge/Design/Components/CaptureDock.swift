import SwiftUI

/// Decision 0025: capture is one tap from anywhere. A 64 pt ember circle (mic
/// with a plus) docked at the bottom trailing corner above the tab bar on
/// every top-level screen. Applied to each tab's root, so it is covered, not
/// carried, when the user opens an idea.
struct CaptureDockButton: View {
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        Button { env.capture = .text } label: {
            ZStack(alignment: .topTrailing) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(ForgeColor.ember, in: Circle())
                    .shadow(color: ForgeColor.ember.opacity(0.4), radius: 16, y: 6)
                Image(systemName: "plus")
                    .font(.system(.footnote, weight: .heavy))
                    .foregroundStyle(ForgeColor.ember)
                    .frame(width: 20, height: 20)
                    .background(.white, in: Circle())
                    .offset(x: -4, y: 4)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("New idea")
        .accessibilityHint("Opens capture. Type or speak; nothing is sent anywhere.")
    }
}

extension View {
    /// The capture dock, bottom trailing, clear of the keyboard.
    func captureDock() -> some View {
        overlay(alignment: .bottomTrailing) {
            CaptureDockButton()
                .padding(.trailing, ForgeSpacing.l)
                .padding(.bottom, ForgeSpacing.m)
        }
    }
}
