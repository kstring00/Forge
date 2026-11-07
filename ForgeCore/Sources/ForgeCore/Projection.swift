import Foundation

/// §4.0 Projection card arithmetic. Everything here is the user's own figures;
/// the card never feeds Potential or Confidence.
public struct Projection: Equatable, Sendable {
    public var pricePerUnit: Double?
    public var unitsYearOne: Int?
    /// Units backed by a real payment attached as Evidence at rung 4 or above.
    public var verifiedUnits: Int

    public init(pricePerUnit: Double? = nil, unitsYearOne: Int? = nil, verifiedUnits: Int = 0) {
        self.pricePerUnit = pricePerUnit
        self.unitsYearOne = unitsYearOne
        self.verifiedUnits = max(0, verifiedUnits)
    }

    public var isEmpty: Bool { pricePerUnit == nil && unitsYearOne == nil }

    /// Derived: price × units, as a monthly figure. Nil until both are entered.
    public var recurringPerMonth: Double? {
        guard let p = pricePerUnit, let u = unitsYearOne, p > 0, u > 0 else { return nil }
        return p * Double(u)
    }

    public var assumedUnits: Int { max(0, (unitsYearOne ?? 0) - verifiedUnits) }

    /// Fraction of the bar that is solid, 0...1.
    public var verifiedFraction: Double {
        guard let u = unitsYearOne, u > 0 else { return 0 }
        return min(1, Double(verifiedUnits) / Double(u))
    }

    /// "$1.8k", "$149", "$12.5k", "$2.1M".
    public static func compact(_ value: Double) -> String {
        let v = abs(value)
        let sign = value < 0 ? "-" : ""
        func trim(_ d: Double, _ suffix: String) -> String {
            let s = d < 10 ? String(format: "%.1f", (d * 10).rounded() / 10) : String(format: "%.0f", d.rounded())
            return sign + "$" + (s.hasSuffix(".0") ? String(s.dropLast(2)) : s) + suffix
        }
        if v >= 1_000_000 { return trim(v / 1_000_000, "M") }
        if v >= 1_000 { return trim(v / 1_000, "k") }
        return sign + "$" + String(format: "%.0f", v.rounded())
    }
}
