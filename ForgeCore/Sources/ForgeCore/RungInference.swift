import Foundation

/// §0A step 6: what the user reports from the world is a user-verified source,
/// and it earns a ladder rung from what the person did: gave time (3), gave
/// money (4), came back (5). Inferred from the words, confirmed by the user.
/// A logged conversation is at least rung 3: someone gave their time.
public enum RungInference {
    public struct Guess: Equatable, Sendable {
        public let rung: Int
        /// The words that decided it, for the sheet to show.
        public let because: String
    }

    static let cameBack: [String] = [
        "came back", "come back", "renewed", "renewal", "reordered", "re-ordered", "referred", "referral", "told a friend",
        "second order", "second time", "again", "reused", "re-used", "kept using", "still using", "recommended us", "recommended me",
    ]
    static let gaveMoney: [String] = [
        "paid", "pays", "payment", "deposit", "invoice", "bought", "buy", "purchase", "preorder", "pre-order", "pilot",
        "letter of intent", "signed a contract", "credit card", "venmo", "zelle", "check for", "cheque", "$", "dollar", "retainer",
    ]
    static let gaveTime: [String] = [
        "talked", "spoke", "conversation", "interview", "call", "called", "meeting", "met with", "replied", "reply", "answered",
        "signed up", "waitlist", "demo", "showed me", "walked me through", "visited", "sat down", "texted back", "wrote back",
        "coffee", "zoom", "facetime", "messaged back", "responded",
    ]

    /// The highest rung the words support, or nil when nothing in them says a
    /// person gave anything. Negations ("didn't pay", "no reply") are stepped down.
    public static func infer(_ text: String) -> Guess? {
        let t = " " + text.lowercased() + " "
        func has(_ words: [String]) -> String? { words.first { t.contains($0) } }
        func negated(_ word: String) -> Bool {
            guard let r = t.range(of: word) else { return false }
            let before = t[t.startIndex..<r.lowerBound].suffix(24)
            return ["didn't", "did not", "never", "no ", "not ", "hasn't", "haven't", "won't", "wouldn't", "refused"].contains { before.contains($0) }
        }
        if let w = has(cameBack), !negated(w) { return Guess(rung: 5, because: "they \(w.trimmingCharacters(in: .whitespaces))") }
        if let w = has(gaveMoney), !negated(w) { return Guess(rung: 4, because: w == "$" ? "money changed hands" : "they \(w.trimmingCharacters(in: .whitespaces))") }
        if let w = has(gaveTime), !negated(w) { return Guess(rung: 3, because: "they \(w.trimmingCharacters(in: .whitespaces))") }
        return nil
    }

    /// For a logged conversation: never below 3, since the person gave time.
    public static func rungForConversation(_ text: String) -> Int {
        max(3, infer(text)?.rung ?? 3)
    }

    public static func label(_ rung: Int) -> String {
        switch rung {
        case 5: "Came back"
        case 4: "Gave money"
        case 3: "Gave time"
        case 2: "Described the problem"
        case 1: "Said it's a good idea"
        default: "Nothing yet"
        }
    }
}
