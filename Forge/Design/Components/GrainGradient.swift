import SwiftUI

/// The idea's sky: a gradient with fine grain multiplied over it, from the
/// design canvas. Grain is deterministic so it never shimmers.
struct GrainGradient: View {
    var colors: [Color]
    /// Overall strength of the grain overlay. The brief's reference is about 0.35.
    var grain: Double = 0.35

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .overlay {
                Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                    var rng = SeededGenerator(seed: 0x5EED)
                    let count = Int(size.width * size.height / 22)
                    for _ in 0..<count {
                        let x = Double.random(in: 0..<size.width, using: &rng)
                        let y = Double.random(in: 0..<size.height, using: &rng)
                        let alpha = Double.random(in: 0.15...1.0, using: &rng) * grain
                        context.fill(
                            Path(CGRect(x: x, y: y, width: 1, height: 1)),
                            with: .color(Color.black.opacity(alpha))
                        )
                    }
                }
                .blendMode(.multiply)
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
    VStack {
        GrainGradient(colors: ForgeColor.sky(for: .capture)).frame(height: 120)
        GrainGradient(colors: ForgeColor.sky(for: .build)).frame(height: 120)
    }
    .padding()
    .background(ForgeColor.canvas)
}
