import SwiftUI
import ForgeCore

/// Warm neutrals, one ember accent used sparingly, one tint per lens.
/// Light and dark values live in Assets.xcassets so the system switches them.
enum ForgeColor {
    static let canvas = Color("Canvas")
    static let surface = Color("Surface")
    static let ink = Color("Ink")
    static let inkSecondary = Color("InkSecondary")
    static let line = Color("Line")
    static let ember = Color("Ember")
    static let sage = Color("Sage")
    static let lavender = Color("Lavender")
    /// AI-generated text is always this colour, with a spark glyph.
    static let spark = Color("Spark")

    static func lensTint(_ lens: LensType?) -> Color {
        switch lens {
        case .business: ember
        case .growth: sage
        case .creative: lavender
        case nil: inkSecondary
        }
    }

    /// Gradient stops for a grain header, by lens. Mood from the sunset reference:
    /// a cool top settling into a warm base.
    static func headerGradient(_ lens: LensType?) -> [Color] {
        switch lens {
        case .business: [Color(red: 0.55, green: 0.62, blue: 0.78), ember.opacity(0.85)]
        case .growth: [Color(red: 0.62, green: 0.70, blue: 0.72), sage]
        case .creative: [Color(red: 0.78, green: 0.72, blue: 0.86), lavender]
        case nil: [Color(red: 0.72, green: 0.70, blue: 0.68), inkSecondary.opacity(0.6)]
        }
    }
}
