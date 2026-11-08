import Foundation

/// §6D: a Reality Check is desk research into a market, so it belongs to the
/// Business lens. Growth and Creative ideas get the Impact card (§4.0) instead.
/// An idea with no lens yet is treated as Business: capture asks nothing, and
/// the one-tap path (§0A) must work on a fresh idea.
public enum RealityCheckPolicy {
    public static func isOffered(for lens: LensType?) -> Bool {
        switch lens {
        case nil, .business?: true
        case .growth?, .creative?: false
        }
    }

    /// Shown where the button would be on a Growth or Creative idea.
    public static let notOfferedLine = "The Reality Check researches markets, so it runs on Business ideas. This lens is judged by its impact instead."
}

/// Decision 0024: when the Brief offers "What if…" pivots. Under 40 Confidence,
/// or a verdict that says the idea as stated is not yet a go.
public enum WhatIfPolicy {
    public static let confidenceFloor = 40

    public static func shows(confidence: Int, verdict: RealityVerdict) -> Bool {
        confidence < confidenceFloor || verdict == .cantTell || verdict == .compete
    }

    /// The label on a card: the weakness the pivot fixes.
    public static func raisesLabel(criterionTitle: String) -> String { "Raises \(criterionTitle)" }
}

/// What a Reality Check costs, in the words the card uses (§0A: cost is visible).
public enum RealityCheckCost {
    /// How many recent real runs the average uses. Recent, so a change in the
    /// proxy's routing shows up after a few checks rather than never.
    public static let averageWindow = 5

    /// Average of the most recent real runs (costs newest first). Nil until one exists.
    public static func average(ofRecent costsNewestFirst: [Double]) -> Double? {
        let real = costsNewestFirst.filter { $0 > 0 }.prefix(averageWindow)
        guard !real.isEmpty else { return nil }
        return real.reduce(0, +) / Double(real.count)
    }

    /// "14¢", "<1¢", "$1.20".
    public static func cents(_ usd: Double) -> String {
        if usd >= 0.995 { return String(format: "$%.2f", usd) }
        let c = Int((usd * 100).rounded())
        if c < 1 { return usd > 0 ? "<1¢" : "0¢" }
        return "\(c)¢"
    }

    /// "10–25¢", or dollars when the top of the range reaches a dollar.
    public static func range(_ r: ClosedRange<Double>) -> String {
        if r.upperBound >= 0.995 { return "\(String(format: "$%.2f", r.lowerBound))–\(String(format: "$%.2f", r.upperBound))" }
        let lo = max(1, Int((r.lowerBound * 100).rounded()))
        let hi = max(lo, Int((r.upperBound * 100).rounded()))
        return lo == hi ? "\(lo)¢" : "\(lo)–\(hi)¢"
    }

    /// The card's line: what runs and what leaves the phone. No price: until
    /// credits (Phase 8), cost appears only in Settings → Spend.
    public static let disclosure = "Runs on AI · your idea text is sent to the model."

    /// Checks started in the calendar month of `now`, and what they cost.
    public static func month(_ checks: [(date: Date, costUSD: Double?)], now: Date = .now, calendar: Calendar = .current) -> (count: Int, spentUSD: Double) {
        let mine = checks.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }
        return (mine.count, mine.reduce(0) { $0 + max(0, $1.costUSD ?? 0) })
    }
}
