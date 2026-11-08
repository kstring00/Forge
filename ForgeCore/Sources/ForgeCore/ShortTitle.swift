import Foundation

/// Every idea has a short name, 2 to 5 words, separate from the words the
/// person said. Captured ideas get one from their first clause; the panel
/// proposes a better one with the Brief; the person can always rename it.
public enum ShortTitle {
    public static let maxWords = 5
    public static let untitled = "Untitled idea"

    private static let leading = [
        "what if", "if", "idea:", "idea", "i want to", "i'd like to", "i would like to", "i think", "maybe", "so",
        "basically", "there was", "there were", "there is", "there's", "we could", "i could", "you could",
        "how about", "a", "an", "the",
    ]
    private static let trailing: Set<String> = [
        "that", "which", "who", "to", "for", "and", "or", "a", "an", "the", "of", "with", "my", "me", "in", "on", "at", "by", "so", "but",
    ]

    /// From the person's words: the first clause, filler stripped, at most five words.
    public static func make(from text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }.first { !$0.isEmpty } ?? ""
        guard !line.isEmpty else { return untitled }
        var clause = firstClause(line)
        var lower = clause.lowercased()
        var stripped = true
        while stripped {
            stripped = false
            for f in leading where lower.hasPrefix(f + " ") || lower == f {
                clause = String(clause.dropFirst(f.count)).trimmingCharacters(in: .whitespaces)
                lower = clause.lowercased()
                stripped = true
                break
            }
        }
        if let t = clamp(clause) { return t }
        return clamp(line) ?? untitled
    }

    /// A proposed title, trimmed to at most five words with no dangling joiner.
    /// Nil when fewer than two words survive.
    public static func clamp(_ text: String) -> String? {
        var words = text
            .replacingOccurrences(of: #"[\"“”.!?…:;]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace).map(String.init)
        if words.count > maxWords { words = Array(words.prefix(maxWords)) }
        while let last = words.last, trailing.contains(last.lowercased().trimmingCharacters(in: .punctuationCharacters)) { words.removeLast() }
        while let last = words.last, last.hasSuffix(",") { words[words.count - 1] = String(last.dropLast()) }
        guard words.count >= 2 else { return nil }
        var t = words.joined(separator: " ")
        t = t.prefix(1).uppercased() + t.dropFirst()
        return t
    }

    public static func wordCount(_ s: String) -> Int { s.split(whereSeparator: \.isWhitespace).count }

    private static func firstClause(_ line: String) -> String {
        if let r = line.range(of: #"[.?!;:,…]|\s[—–-]\s"#, options: .regularExpression) {
            let head = String(line[..<r.lowerBound]).trimmingCharacters(in: .whitespaces)
            if wordCount(head) >= 2 { return head }
        }
        return line
    }
}
