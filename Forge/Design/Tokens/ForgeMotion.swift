import SwiftUI

/// Subtle. Cards settle, stages slide. Nothing bounces for attention.
enum ForgeMotion {
    static let settle = Animation.spring(response: 0.42, dampingFraction: 0.92)
    static let slide = Animation.easeInOut(duration: 0.24)
    static let fade = Animation.easeOut(duration: 0.18)
}

private struct ForgeAnimationModifier<V: Equatable>: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let animation: Animation
    let value: V

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? nil : animation, value: value)
    }
}

extension View {
    /// Applies an animation unless Reduce Motion is on.
    func forgeAnimation<V: Equatable>(_ animation: Animation, value: V) -> some View {
        modifier(ForgeAnimationModifier(animation: animation, value: value))
    }
}
