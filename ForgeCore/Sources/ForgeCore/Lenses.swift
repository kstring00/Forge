import Foundation

/// The registry of lenses. Content lives in the LensA/B/C files; nothing
/// here is stored in the database.
public enum Lenses {
    public static let business = LensA.lens
    public static let growth = LensB.lens
    public static let creative = LensC.lens

    public static let all: [Lens] = [business, growth, creative]

    public static func lens(for type: LensType) -> Lens {
        switch type {
        case .business: business
        case .growth: growth
        case .creative: creative
        }
    }

    public static func criterion(_ key: String, in type: LensType) -> Criterion? {
        lens(for: type).criterion(key)
    }
}
