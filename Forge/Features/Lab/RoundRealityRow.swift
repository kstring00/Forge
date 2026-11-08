import SwiftUI
import ForgeCore

/// Under Next move: Run a Round (three orbs). The Reality Check lives on the
/// Brief and on the idea before its first check, so it is not repeated here.
struct RoundRealityRow: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(spacing: 10) {
                Button { tap("Run a Round") } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "waveform").font(.system(size: 13, weight: .medium))
                        Text("Run a Round")
                    }
                    .frame(maxWidth: .infinity)
                    .modifier(SecondaryButtonChrome())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Run a Round with the Sphere panel")
            }
            if let message {
                HStack(alignment: .top) {
                    Text(message).font(.caption).foregroundStyle(ForgeColor.inkSecondary)
                    Spacer()
                    Button("OK") { self.message = nil }.font(.caption.weight(.medium))
                }
            }
        }
    }

    private func tap(_ name: String) {
        if env.ai.isAvailable {
            message = "\(name) arrives with the next build."
        } else {
            message = "\(name) needs the AI proxy, which isn't connected yet. Your scores and evidence are saved here."
        }
    }
}

struct SecondaryButtonChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(ForgeColor.ink)
            .padding(14)
            .background(ForgeColor.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(ForgeColor.line))
    }
}
