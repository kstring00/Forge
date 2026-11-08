import Foundation

/// Two Spheres, unordered, held in the order the orbs sit on screen.
public struct SpherePair: Hashable, Sendable, Identifiable {
    public let a: Sphere
    public let b: Sphere

    public init(_ x: Sphere, _ y: Sphere) {
        let ix = Panel.order.firstIndex(of: x) ?? 0
        let iy = Panel.order.firstIndex(of: y) ?? 0
        (a, b) = ix <= iy ? (x, y) : (y, x)
    }

    public var id: String { "\(a.rawValue)|\(b.rawValue)" }
    public func contains(_ s: Sphere) -> Bool { a == s || b == s }
    public func other(than s: Sphere) -> Sphere { a == s ? b : a }

    /// How many orb slots apart the two sit. The hairline arcs higher the
    /// further apart they are, so lines never lie on top of each other.
    public var span: Int {
        abs((Panel.order.firstIndex(of: b) ?? 0) - (Panel.order.firstIndex(of: a) ?? 0))
    }
}

/// §6C and §8: who disagrees with whom, and where a Round stands.
public enum Panel {
    /// The order the orbs sit in, left to right.
    public static let order: [Sphere] = [.customer, .investor, .strategist, .builder, .skeptic, .steward]

    /// Two Spheres disagree when one says on track and the other off track.
    /// "Can't tell" disagrees with nobody: it is an absence of evidence, not
    /// a position. Only these pairs get a hairline and a crossfire.
    public static func conflicts(_ verdicts: [(sphere: Sphere, kind: VerdictKind)]) -> [SpherePair] {
        var firstKind: [Sphere: VerdictKind] = [:]
        for v in verdicts where firstKind[v.sphere] == nil { firstKind[v.sphere] = v.kind }
        let on = order.filter { firstKind[$0] == .onTrack }
        let off = order.filter { firstKind[$0] == .offTrack }
        var pairs: [SpherePair] = []
        for x in on { for y in off { pairs.append(SpherePair(x, y)) } }
        return pairs.sorted {
            if $0.span != $1.span { return $0.span < $1.span }
            return (order.firstIndex(of: $0.a) ?? 0) < (order.firstIndex(of: $1.a) ?? 0)
        }
    }

    public static func isConflict(_ x: VerdictKind, _ y: VerdictKind) -> Bool {
        (x == .onTrack && y == .offTrack) || (x == .offTrack && y == .onTrack)
    }
}

/// §6C step 5: where the panel agreed, where it split, and the user's rulings.
public struct RoundTally: Equatable, Sendable {
    public var onTrack = 0
    public var offTrack = 0
    public var cantTell = 0
    public var agreed = 0
    public var disagreed = 0
    public var findOut = 0
    public var unruled = 0
    public var splits: [SpherePair] = []

    public init() {}

    public init(_ verdicts: [(sphere: Sphere, kind: VerdictKind, ruling: RulingChoice?)]) {
        for v in verdicts {
            switch v.kind {
            case .onTrack: onTrack += 1
            case .offTrack: offTrack += 1
            case .cantTell: cantTell += 1
            }
            switch v.ruling {
            case .agree?: agreed += 1
            case .disagree?: disagreed += 1
            case .findOut?: findOut += 1
            case nil: unruled += 1
            }
        }
        splits = Panel.conflicts(verdicts.map { ($0.sphere, $0.kind) })
    }

    public var ruled: Int { agreed + disagreed + findOut }
    public var total: Int { ruled + unruled }
    public var isComplete: Bool { total > 0 && unruled == 0 }
    /// Agree is the default: unruled verdicts count as agreed once the user
    /// moves on, so only disagreements and find-outs need saying.
    public var exceptions: Int { disagreed + findOut }

    /// "2 disagreements · 1 to find out", or "Agreed with every voice".
    public var rulingsLine: String {
        if total == 0 { return "No verdicts yet." }
        var parts: [String] = []
        if disagreed > 0 { parts.append(disagreed == 1 ? "1 disagreement" : "\(disagreed) disagreements") }
        if findOut > 0 { parts.append("\(findOut) to find out") }
        return parts.isEmpty ? "Agreed with every voice" : parts.joined(separator: " · ")
    }

    /// One plain line for the summary: where the panel stood.
    public var panelLine: String {
        if total == 0 { return "The panel has no verdicts yet." }
        if splits.isEmpty {
            return offTrack == 0 && onTrack == 0
                ? "Nobody could tell from the desk."
                : "No Sphere contradicted another."
        }
        return splits.count == 1 ? "The panel split once." : "The panel split \(splits.count) ways."
    }
}
