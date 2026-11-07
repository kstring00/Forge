import SwiftUI

/// Soft gradient with fine grain, from the sunset reference. Used as the
/// header material on idea detail. Grain is deterministic and cheap.
struct GrainGradient: View {
    var colors: [Color]
    var grain: Double = 0.10

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .overlay {
                Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                    var rng = SeededGenerator(seed: 0x5EED)
                    let count = Int(size.width * size.height / 28)
                    for _ in 0..<count {
                        let x = Double.random(in: 0..<size.width, using: &rng)
                        let y = Double.random(in: 0..<size.height, using: &rng)
                        let alpha = Double.random(in: 0.2...1.0, using: &rng) * grain
                        let light = Bool.random(using: &rng)
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color((light ? Color.white : Color.black).opacity(alpha))
                        )
                    }
                }
                .allowsHitTesting(false)
            }
            .drawingGroup()
            .accessibilityHidden(true)
    }
}

/// Small deterministic generator so the grain never shimmers between redraws.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

#Preview {
    GrainGradient(colors: ForgeColor.headerGradient(.business))
        .frame(height: 260)
}
