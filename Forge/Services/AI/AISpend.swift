import Foundation

/// Brief v4 §0A: cost is visible. A monthly total of what the proxy reported,
/// against a ceiling the user sets in Settings. Stored in UserDefaults.
enum AISpend {
    static let monthKey = "ai.spend.month"
    static let totalKey = "ai.spend.usd"
    static let ceilingKey = "ai.ceiling.usd"
    static let lastCheckKey = "ai.lastRealityCheckUSD"
    static let defaultCeiling: Double = 10
    nonisolated(unsafe) static var defaults: UserDefaults = .standard

    static func currentMonth(_ date: Date = .now) -> String {
        let c = Calendar.current.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    static var ceilingUSD: Double {
        get { let v = defaults.double(forKey: ceilingKey); return v > 0 ? v : defaultCeiling }
        set { defaults.set(newValue, forKey: ceilingKey) }
    }

    static func spentUSD(now: Date = .now) -> Double {
        guard defaults.string(forKey: monthKey) == currentMonth(now) else { return 0 }
        return defaults.double(forKey: totalKey)
    }

    static func remainingUSD(now: Date = .now) -> Double {
        max(0, ceilingUSD - spentUSD(now: now))
    }

    static func record(_ cost: Double, now: Date = .now) {
        guard cost > 0 else { return }
        let month = currentMonth(now)
        let base = defaults.string(forKey: monthKey) == month ? defaults.double(forKey: totalKey) : 0
        defaults.set(month, forKey: monthKey)
        defaults.set(base + cost, forKey: totalKey)
    }

    static func wouldExceed(estimate: Double, now: Date = .now) -> Bool {
        spentUSD(now: now) + estimate > ceilingUSD
    }

    static var lastRealityCheckUSD: Double? {
        get { let v = defaults.double(forKey: lastCheckKey); return v > 0 ? v : nil }
        set { defaults.set(newValue ?? 0, forKey: lastCheckKey) }
    }

    static func format(_ usd: Double) -> String {
        usd < 0.01 && usd > 0 ? "<$0.01" : String(format: "$%.2f", usd)
    }
}
