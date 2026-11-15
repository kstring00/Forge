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
    /// person gave anything. Negations ("didn't pay", "no reply") are stepped
    /// down, and money paid to someone else ("she pays a nephew") is not money
    /// given for this idea: it is a workaround, heard in a conversation.
    public static func infer(_ text: String) -> Guess? {
        let t = " " + text.lowercased() + " "
        let money = " " + withoutPaymentsToOthers(text.lowercased()) + " "
        func has(_ words: [String], in t: String) -> String? { words.first { t.contains($0) } }
        func negated(_ word: String, in t: String) -> Bool {
            guard let r = t.range(of: word) else { return false }
            let before = t[t.startIndex..<r.lowerBound].suffix(24)
            return ["didn't", "did not", "never", "no ", "not ", "hasn't", "haven't", "won't", "wouldn't", "refused"].contains { before.contains($0) }
        }
        if let w = has(cameBack, in: t), !negated(w, in: t) { return Guess(rung: 5, because: "they \(w.trimmingCharacters(in: .whitespaces))") }
        if let w = has(gaveMoney, in: money), !negated(w, in: money) { return Guess(rung: 4, because: w == "$" ? "money changed hands" : "they \(w.trimmingCharacters(in: .whitespaces))") }
        if let w = has(gaveTime, in: t), !negated(w, in: t) { return Guess(rung: 3, because: "they \(w.trimmingCharacters(in: .whitespaces))") }
        // Hearing that they pay someone else came out of a conversation.
        if money != t { return Guess(rung: 3, because: "they told you what they pay for today") }
        return nil
    }

    static let payVerbs: Set<String> = ["pay", "pays", "paid", "paying"]
    /// What follows the verb when the money goes to someone else: "pays a nephew", "paid their agency".
    static let toSomeone: Set<String> = ["a", "an", "her", "his", "their", "some", "another"]
    /// What follows it when the money is the payment itself: "paid a deposit", "paid her first month".
    static let paymentWords: Set<String> = [
        "deposit", "retainer", "invoice", "fee", "bill", "pilot", "month", "months", "year", "subscription", "preorder", "pre-order",
        "down", "first", "second", "full", "half", "partial", "small", "little", "lot", "few", "bit", "share", "balance", "total",
        "monthly", "yearly", "annual", "one-time", "setup", "flat", "refundable", "trial",
    ]

    /// The text without the sentences where the only payment is to someone
    /// else. A sentence that also pays "me" or "us", or names the payment
    /// ("paid a $149 deposit"), stays.
    static func withoutPaymentsToOthers(_ text: String) -> String {
        let sentences = text.split(omittingEmptySubsequences: false) { ";!?\n".contains($0) || $0 == "." }
        let kept = sentences.filter { !paysOnlySomeoneElse($0) }
        return kept.count == sentences.count ? text : kept.joined(separator: ".")
    }

    static func paysOnlySomeoneElse(_ sentence: Substring) -> Bool {
        let words = sentence.split { $0 == " " || $0 == "," || $0 == "\t" }.map { $0.trimmingCharacters(in: .punctuationCharacters) }
        var toOthers = false
        for (i, w) in words.enumerated() where payVerbs.contains(w) && i + 1 < words.count {
            let next = words[i + 1]
            if next == "someone" || next == "somebody" { toOthers = true; continue }
            guard toSomeone.contains(next), i + 2 < words.count else { return false }
            let object = words[i + 2]
            if object.first == "$" || object.first?.isNumber == true || paymentWords.contains(object) { return false }
            toOthers = true
        }
        return toOthers
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
