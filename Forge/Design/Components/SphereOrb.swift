import SwiftUI
import ForgeCore

/// A Sphere is a blurred radial-gradient orb in its own palette. No faces,
/// no icons; the orb is the whole identity.
struct SphereOrb: View {
    let sphere: Sphere
    var size: CGFloat = 28

    var body: some View {
        let tint = ForgeColor.sphereTint(sphere)
        Circle()
            .fill(
                RadialGradient(
                    colors: [tint.opacity(0.95), tint.opacity(0.55), tint.opacity(0.0)],
                    center: UnitPoint(x: 0.38, y: 0.35),
                    startRadius: 0,
                    endRadius: size * 0.6
                )
            )
            .frame(width: size, height: size)
            .blur(radius: size * 0.06)
            .accessibilityLabel(sphere.displayName)
    }
}

#Preview {
    HStack(spacing: 16) {
        ForEach(Sphere.allCases) { SphereOrb(sphere: $0, size: 36) }
    }
    .padding()
    .background(ForgeColor.canvas)
}
