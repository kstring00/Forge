import SwiftUI
import ForgeCore

/// Brief v3.1 §8. Dark is the default theme: deep matte charcoal ground with
/// one ember accent used only for capture, "next step" and the Confidence ring.
/// Light inverts the same tokens. Values live in Assets.xcassets.
enum ForgeColor {
    static let canvas = Color("Canvas")              // ground   #1C1916
    static let surface = Color("Surface")            // cards    #272320
    static let line = Color("Line")                  // hairline #3A342E
    static let ink = Color("Ink")                    // text     #F1EBE2
    static let inkSecondary = Color("InkSecondary")  // muted    #A39B8F
    static let ember = Color("Ember")                // fills    #C4441C
    static let emberText = Color("EmberText")        // as text  #E58A62
    /// AI-generated text is muted sans with a spark glyph.
    static let spark = Color("Spark")

    static let copper = Color("Copper")
    static let sage = Color("Sage")
    static let lavender = Color("Lavender")

    static func lensTint(_ lens: LensType?) -> Color {
        switch lens {
        case .business: copper
        case .growth: sage
        case .creative: lavender
        case nil: inkSecondary
        }
    }

    /// Spheres are orbs with their own palette; the orb is the whole identity.
    static func sphereTint(_ sphere: Sphere) -> Color {
        switch sphere {
        case .customer: Color("SphereBlue")
        case .investor: ember
        case .strategist: Color("SphereViolet")
        case .builder: Color("SphereGreen")
        case .skeptic: Color("SphereStone")
        case .steward: Color("SphereGold")
        }
    }

    // MARK: The idea's sky

    /// Lavender settling into a base that is cool and quiet at Capture and
    /// warms toward ember as the idea moves to Build. The only large colour field.
    static func sky(for stage: Stage) -> [Color] {
        let t: Double = switch stage {
        case .capture: 0.0
        case .explore: 0.3
        case .evaluate: 0.55
        case .build: 0.85
        case .launch: 1.0
        case .archived: 0.1
        }
        let top = RGB(0x8F, 0x82, 0xC8)             // lavender
        let coolBase = RGB(0x4E, 0x5A, 0x7A)        // slate
        let emberBase = RGB(0xC4, 0x44, 0x1C)       // ember
        return [top.color, RGB.mix(coolBase, emberBase, t).color]
    }

    /// Small helper for mixing fixed colours without an asset per stage.
    struct RGB {
        var r: Double, g: Double, b: Double
        init(_ r: Int, _ g: Int, _ b: Int) { self.r = Double(r) / 255; self.g = Double(g) / 255; self.b = Double(b) / 255 }
        init(r: Double, g: Double, b: Double) { self.r = r; self.g = g; self.b = b }
        var color: Color { Color(red: r, green: g, blue: b) }
        static func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB {
            let k = min(max(t, 0), 1)
            return RGB(r: a.r + (b.r - a.r) * k, g: a.g + (b.g - a.g) * k, b: a.b + (b.b - a.b) * k)
        }
    }
}
