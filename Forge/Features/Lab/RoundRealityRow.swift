import SwiftUI
import ForgeCore

/// The pair under Next move: Run a Round (three orbs) and Reality Check.
/// Both need the proxy; until it is connected they say so calmly.
struct RoundRealityRow: View {
    let idea: Idea
    @Environment(AppEnvironment.self) private var env
    @State private var message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ForgeSpacing.s) {
            HStack(spacing: 10) {
                Button { tap("Run a Round") } label: {
                    HStack(spacing: 10) {
                        HStack(spacing: -4) {
                            SphereOrb(sphere: .investor, size: 14)
                            SphereOrb(sphere: .customer, size: 14)
                            SphereOrb(sphere: .strategist, size: 14)
                        }
                        Text("Run a Round")
                    }
                    .frame(maxWidth: .infinity)
                    .modifier(SecondaryButtonChrome())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Run a Round with the Sphere panel")

                Button { tap("Reality Check") } label: {
                    Text("Reality Check")
                        .frame(maxWidth: .infinity)
                        .modifier(SecondaryButtonChrome())
                }
                .buttonStyle(.plain)
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
