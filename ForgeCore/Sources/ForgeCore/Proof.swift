import Foundation

/// Decision 0037 (docs/ENGINE.md §3.2): how much a source counts as evidence.
/// Lived evidence (the person's own conversations, signups, payments) always
/// outranks any desk score; a model's own reasoning never counts.
public enum EvidenceRank: String, Codable, Sendable, CaseIterable {
    case lived, published, reviewed, discussed, opinion

    /// What one independent desk source adds to a criterion's level.
    public var deskWeight: Double {
        switch self {
        case .lived: 0
        case .published: 0.4
        case .reviewed: 0.35
        case .discussed: 0.2
        case .opinion: 0
        }
    }

    public var displayName: String {
        switch self {
        case .lived: "your own evidence"
        case .published: "published"
        case .reviewed: "reviews"
        case .discussed: "forums and posts"
        case .opinion: "opinion"
        }
    }

    private static let reviewHosts = ["g2.com", "capterra.com", "trustpilot.com", "yelp.com", "tripadvisor.com", "apps.apple.com",
                                      "play.google.com", "producthunt.com", "getapp.com", "softwareadvice.com", "bbb.org", "glassdoor.com",
                                      "consumerreports.org", "sitejabber.com", "reviews.io", "google.com/maps"]
    private static let discussionHosts = ["reddit.com", "quora.com", "news.ycombinator.com", "twitter.com", "x.com", "facebook.com",
                                          "tiktok.com", "youtube.com", "medium.com", "substack.com", "stackexchange.com", "stackoverflow.com",
                                          "discord.com", "linkedin.com", "threads.net", "instagram.com"]

    /// From a fetched page's address. Model-written notes are opinion.
    public static func classify(url: String?, modelWritten: Bool = false) -> EvidenceRank {
        if modelWritten { return .opinion }
        guard let url, let host = DeskGrade.host(url) else { return .opinion }
        let path = url.lowercased()
        if reviewHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) || path.contains($0) }) || path.contains("/reviews") { return .reviewed }
        if discussionHosts.contains(where: { host == $0 || host.hasSuffix("." + $0) }) || host.hasPrefix("forum") || host.hasPrefix("community")
            || path.contains("/forum") || path.contains("/community/") || path.contains("/threads/") || path.contains("/discussion") { return .discussed }
        return .published
    }
}

/// A criterion's desk level: 1.0 plus what its independent sources add, at
/// most 2.0 (the desk ceiling). One forum post ≈ 1.2; three independent
/// reviewed sources = 2.0. Sources on one site count once.
public enum DeskGrade {
    public struct Result: Equatable, Sendable {
        public var level: Double
        public var independentSources: Int
    }

    public static let floor = 1.0
    public static let ceiling = 2.0

    public static func level(sources: [(url: String?, rank: EvidenceRank)], proposedLevel: Int) -> Result {
        var bestPerSite: [String: Double] = [:]
        for s in sources where s.rank.deskWeight > 0 {
            let site = s.url.flatMap(host) ?? "unknown-\(bestPerSite.count)"
            bestPerSite[site] = max(bestPerSite[site] ?? 0, s.rank.deskWeight)
        }
        guard !bestPerSite.isEmpty else {
            return Result(level: Double(min(max(proposedLevel, 0), 1)), independentSources: 0)
        }
        let level = min(ceiling, floor + bestPerSite.values.reduce(0, +))
        return Result(level: (level * 10).rounded() / 10, independentSources: bestPerSite.count)
    }

    /// "www.g2.com" → "g2.com"; "forum.example.co.uk" → "forum.example.co.uk" minus www.
    public static func host(_ url: String) -> String? {
        guard let h = URL(string: url)?.host?.lowercased(), !h.isEmpty else { return nil }
        return h.hasPrefix("www.") ? String(h.dropFirst(4)) : h
    }
}

/// A change in proof, kept on the idea: the card shows it for a day, the
/// Brief keeps it for good. "+7 from Dale".
public struct ProofMove: Codable, Hashable, Sendable, Identifiable {
    public var id: UUID
    public var at: Date
    /// Change in how sure we are, in points out of 100.
    public var delta: Int
    /// Who or what moved it: a name, "a conversation", "a payment".
    public var from: String
    public var criterionTitle: String?
    public var levelAfter: Int

    public init(id: UUID = UUID(), at: Date, delta: Int, from: String, criterionTitle: String?, levelAfter: Int) {
        self.id = id
        self.at = at
        self.delta = delta
        self.from = from
        self.criterionTitle = criterionTitle
        self.levelAfter = levelAfter
    }

    /// "+7 from Dale"
    public var line: String { "\(delta >= 0 ? "+" : "")\(delta) from \(from)" }

    public func isRecent(now: Date = .now) -> Bool { now.timeIntervalSince(at) < 24 * 3600 }
}

/// Decision 0037: the Investor's return, built bottom-up for this idea:
/// price × reachable customers × conversion. Each input says what it rests on,
/// or is an assumption. No range wider than 10×; with no price for this idea,
/// it is too early to estimate.
public struct ReturnInputs: Codable, Hashable, Sendable {
    public struct Input: Codable, Hashable, Sendable {
        public var low: Double
        public var high: Double
        /// What it rests on, in a few words.
        public var basis: String
        /// The source it came from, if any. Nil is an assumption.
        public var sourceID: UUID?
        public var sourceTitle: String?

        public init(low: Double, high: Double, basis: String, sourceID: UUID? = nil, sourceTitle: String? = nil) {
            self.low = min(low, high)
            self.high = max(low, high)
            self.basis = basis
            self.sourceID = sourceID
            self.sourceTitle = sourceTitle
        }

        public var isAssumption: Bool { sourceID == nil }
    }

    /// What one paying customer pays per month for this idea.
    public var price: Input
    /// Customers the person could reach in year one.
    public var reachable: Input
    /// The share of those who pay, 0 to 1.
    public var conversion: Input

    public init(price: Input, reachable: Input, conversion: Input) {
        self.price = price
        self.reachable = reachable
        var c = conversion
        c.low = min(max(c.low, 0), 1)
        c.high = min(max(c.high, 0), 1)
        self.conversion = c
    }

    public enum Outcome: Equatable, Sendable {
        /// Monthly, low to high. `narrowed` when the inputs spanned more than 10×.
        case range(low: Double, high: Double, narrowed: Bool)
        case tooEarly(String)
    }

    public static let maxSpread = 10.0
    public static let noPrice = "Too early to estimate: no price found"

    public var outcome: Outcome {
        let all = [price, reachable, conversion]
        if all.allSatisfy(\.isAssumption) || price.isAssumption || price.high <= 0 { return .tooEarly(Self.noPrice) }
        var low = price.low * reachable.low * conversion.low
        let high = price.high * reachable.high * conversion.high
        guard high > 0 else { return .tooEarly("Too early to estimate: nobody to sell to yet") }
        if low <= 0 { low = high / Self.maxSpread }
        guard high / low > Self.maxSpread else { return .range(low: low, high: high, narrowed: false) }
        // Wider than 10×: keep the middle, at 10× wide, and say so.
        let mid = (low * high).squareRoot()
        let half = Self.maxSpread.squareRoot()
        return .range(low: mid / half, high: mid * half, narrowed: true)
    }
}
