import Foundation

/// A free, on-device check before any Reality Check. If the idea gives the
/// panel nothing to look into, the run is blocked and no proxy call is made.
public enum IdeaGuard {
    public enum Verdict: Equatable, Sendable {
        case ok
        /// Under the minimum word count.
        case tooShort
        /// Long enough, but names neither a problem nor a person.
        case noSubject
    }

    public static let minimumWords = 8

    /// Shown in place of the button when a check is blocked.
    public static let blockedLine = "Add a sentence about the problem and who has it, so the panel has something to look into."

    public static func check(_ text: String) -> Verdict {
        let words = text.split { !$0.isLetter && !$0.isNumber && $0 != "'" && $0 != "-" }
        if words.count < minimumWords { return .tooShort }
        let lower = " " + text.lowercased() + " "
        let hasPerson = personWords.contains { lower.contains(" \($0)") }
        let hasProblem = problemWords.contains { lower.contains($0) }
        return hasPerson || hasProblem ? .ok : .noSubject
    }

    /// Who could have the problem: roles, groups and the words that introduce them.
    static let personWords: [String] = [
        "people", "person", "customer", "client", "user", "owner", "parent", "kid", "child", "teacher", "student",
        "nurse", "doctor", "patient", "founder", "team", "business", "company", "shop", "store", "park", "family",
        "friend", "men", "women", "folks", "someone", "anyone", "everyone", "who ", "whose", "for ", "they ", "them ",
        "manager", "driver", "farmer", "renter", "landlord", "buyer", "seller", "freelancer", "creator", "artist",
        "writer", "developer", "designer", "coach", "player", "fan", "member", "neighbor", "neighbour", "community",
        "me ", "myself", "i ", "my ",
    ]

    /// What goes wrong, or what is wanted.
    static let problemWords: [String] = [
        "problem", "pain", "hate", "struggl", "can't", "cannot", "can not", "wish", "need", "waste", "slow", "expensive",
        "hard to", "annoy", "complain", "frustrat", "miss", "fail", "lose", "lost", "forget", "ignore", "no way to",
        "instead of", "nothing else", "nobody", "no one", "never", "stuck", "confus", "cost", "costs", "too ", "broken",
        "manual", "spreadsheet", "every time", "hours", "late", "wait", "risk", "unsafe", "danger", "doesn't", "don't",
        "isn't", "aren't", "won't", "without", "lack", "gap", "want", "solve", "fix", "help", "easier", "faster", "cheaper",
        "better", "replace", "tired of", "sick of",
    ]
}

/// Numbers written as words, one through twenty, and digits.
public enum NumberWords {
    static let words: [String: Int] = [
        "one": 1, "two": 2, "three": 3, "four": 4, "five": 5, "six": 6, "seven": 7, "eight": 8, "nine": 9, "ten": 10,
        "eleven": 11, "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15, "sixteen": 16, "seventeen": 17,
        "eighteen": 18, "nineteen": 19, "twenty": 20, "a dozen": 12, "half a dozen": 6,
    ]

    /// The first count in the text, as a digit or a word. "Talk to five parents" → 5.
    public static func firstNumber(in text: String) -> Int? {
        let lower = text.lowercased()
        var best: (index: String.Index, value: Int)?
        if let r = lower.range(of: #"\b\d{1,3}\b"#, options: .regularExpression), let n = Int(lower[r]) {
            best = (r.lowerBound, n)
        }
        for (word, value) in words {
            guard let r = lower.range(of: #"\b"# + word + #"\b"#, options: .regularExpression) else { continue }
            if best == nil || r.lowerBound < best!.index { best = (r.lowerBound, value) }
        }
        return best?.value
    }
}

/// The model sometimes echoes a source id into prose. Users never see ids: a
/// known id becomes the source's title; an unknown one disappears.
public enum IDScrub {
    static let uuid = #"[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}"#

    public static func containsID(_ text: String) -> Bool {
        text.range(of: uuid, options: .regularExpression) != nil
    }

    public static func scrub(_ text: String, titles: [UUID: String] = [:]) -> String {
        guard containsID(text) else { return text }
        var out = text
        // Common wrappers first: "(source 1234-…)", "[id: 1234-…]", "source id=1234-…".
        let wrapped = #"[\(\[]\s*(?:source|src|id|source id)?\s*[:=]?\s*"# + uuid + #"\s*[\)\]]"#
        out = replace(wrapped, in: out) { m in
            if let id = firstUUID(in: m), let t = titles[id] { return "(\(t))" }
            return ""
        }
        let prefixed = #"(?:source|src|id|source id)\s*[:=]?\s*"# + uuid
        out = replace(prefixed, in: out) { m in
            if let id = firstUUID(in: m), let t = titles[id] { return t }
            return ""
        }
        out = replace(uuid, in: out) { m in
            if let id = UUID(uuidString: m), let t = titles[id] { return t }
            return ""
        }
        // Tidy what the removals left behind.
        out = out.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\s+([,.;:)])"#, with: "$1", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\(\s*\)"#, with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: #",\s*,"#, with: ",", options: .regularExpression)
        out = out.replacingOccurrences(of: #"\s+([,.;:)])"#, with: "$1", options: .regularExpression)
        return out.trimmingCharacters(in: .whitespaces)
    }

    private static func firstUUID(in s: String) -> UUID? {
        guard let r = s.range(of: uuid, options: .regularExpression) else { return nil }
        return UUID(uuidString: String(s[r]))
    }

    private static func replace(_ pattern: String, in text: String, with f: (String) -> String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return text }
        let ns = text as NSString
        var out = text
        for m in re.matches(in: text, range: NSRange(location: 0, length: ns.length)).reversed() {
            let piece = ns.substring(with: m.range)
            out = (out as NSString).replacingCharacters(in: m.range, with: f(piece))
        }
        return out
    }
}
