import Foundation

/// One line a day at the top of the Idea tab. Every entry is verifiable:
/// text, who said it, and where. Nothing is paraphrased.
public struct Quote: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable { case scripture, secular }

    public let text: String
    public let author: String
    /// Where it comes from, for the attribution line and for checking.
    public let source: String
    public let kind: Kind

    public var id: String { text }
    /// "Steve Jobs · to the Macintosh team, 1983"
    public var attribution: String { source.isEmpty ? author : "\(author) · \(source)" }
}

/// Which quotes the user wants, set in Settings.
public enum QuotesSetting: String, CaseIterable, Sendable, Identifiable {
    case all, scripture, secular, off

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .all: "All"
        case .scripture: "Scripture only"
        case .secular: "Secular only"
        case .off: "Off"
        }
    }

    func allows(_ q: Quote) -> Bool {
        switch self {
        case .all: true
        case .scripture: q.kind == .scripture
        case .secular: q.kind == .secular
        case .off: false
        }
    }
}

public enum Quotes {
    public static let all: [Quote] = [
        Quote(text: "Real artists ship.", author: "Steve Jobs", source: "to the Macintosh team, 1983", kind: .secular),
        Quote(text: "Make something people want.", author: "Paul Graham", source: "Y Combinator's motto", kind: .secular),
        Quote(text: "If you are not embarrassed by the first version of your product, you've launched too late.", author: "Reid Hoffman", source: "", kind: .secular),
        Quote(text: "Creativity is just connecting things.", author: "Steve Jobs", source: "Wired, 1996", kind: .secular),
        Quote(text: "You can't use up creativity. The more you use, the more you have.", author: "Maya Angelou", source: "", kind: .secular),
        Quote(text: "All hard work brings a profit, but mere talk leads only to poverty.", author: "Proverbs 14:23", source: "NIV", kind: .scripture),
        Quote(text: "The plans of the diligent lead to profit as surely as haste leads to poverty.", author: "Proverbs 21:5", source: "NIV", kind: .scripture),
        Quote(text: "Commit to the Lord whatever you do, and he will establish your plans.", author: "Proverbs 16:3", source: "NIV", kind: .scripture),
        Quote(text: "In their hearts humans plan their course, but the Lord establishes their steps.", author: "Proverbs 16:9", source: "NIV", kind: .scripture),
    ]

    /// The quote for a day: rotates daily through what the setting allows, in
    /// a fixed order, so the same day shows the same line. Nil when off.
    public static func forDay(_ date: Date, setting: QuotesSetting, calendar: Calendar = .current) -> Quote? {
        let allowed = all.filter(setting.allows)
        guard !allowed.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return allowed[day % allowed.count]
    }

    /// "2026-11-08", the key a dismissal is stored under.
    public static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
