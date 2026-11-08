import Foundation
import ForgeCore

/// Decision 0030: one filled-in interview. Lives on the project as a value
/// (no new table): a draft saves itself as you type; Done turns it into one
/// logged conversation, a user-verified source with every question and answer.
public struct Interview: Codable, Hashable, Identifiable, Sendable {
    public struct Answer: Codable, Hashable, Sendable {
        public var question: String
        public var answer: String
        public init(question: String, answer: String = "") {
            self.question = question
            self.answer = answer
        }
    }

    public enum Status: String, Codable, Sendable { case draft, done }

    public var id: UUID
    /// A name or a nickname.
    public var who: String
    /// Who they are: "runs a daycare in Katy".
    public var whoIs: String
    public var answers: [Answer]
    public var status: Status
    public var createdAt: Date
    public var updatedAt: Date
    /// The rung confirmed at Done.
    public var rung: Int?
    /// The user-verified Source it became.
    public var sourceID: UUID?

    public init(id: UUID = UUID(), who: String = "", whoIs: String = "", questions: [String], createdAt: Date = .now) {
        self.id = id
        self.who = who
        self.whoIs = whoIs
        self.answers = questions.map { Answer(question: $0) }
        self.status = .draft
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }

    public var isDraft: Bool { status == .draft }
    public var answeredCount: Int { answers.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count }
    public var hasContent: Bool { answeredCount > 0 || !who.trimmingCharacters(in: .whitespaces).isEmpty }

    /// "Spoke with Maria (runs a daycare)" for lists.
    public var headline: String {
        let name = who.trimmingCharacters(in: .whitespaces)
        let role = whoIs.trimmingCharacters(in: .whitespaces)
        switch (name.isEmpty, role.isEmpty) {
        case (false, false): return "\(name) · \(role)"
        case (false, true): return name
        case (true, false): return role
        case (true, true): return "Someone"
        }
    }

    /// The whole conversation as plain text: what the Source holds and what Share sends.
    public var transcript: String {
        var lines = ["Interview with \(headline)"]
        for a in answers where !a.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("")
            lines.append("Q: \(a.question)")
            lines.append("A: \(a.answer.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return lines.joined(separator: "\n")
    }
}

/// The question list: from the panel's drafted asset, editable, shared as text.
public enum InterviewQuestions {
    /// Five Mom Test questions, used when no asset was drafted.
    public static let fallback = [
        "When did this last come up for you? Walk me through what happened.",
        "What did you do about it? What did that cost you, in time or money?",
        "What else have you tried? Why did you stop?",
        "Who else was involved in that decision?",
        "If this went away tomorrow, what would change for you?",
    ]

    /// Numbered or bulleted lines become questions; prose lines that end in a
    /// question mark count too. Anything else (headings, notes) is left out.
    public static func parse(_ body: String) -> [String] {
        var out: [String] = []
        for raw in body.components(separatedBy: .newlines) {
            var line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            let numbered = line.range(of: #"^(\d+[.)]|[-•*])\s+"#, options: .regularExpression)
            if let numbered {
                line.removeSubrange(numbered)
            } else if !line.hasSuffix("?") {
                continue
            }
            line = line.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("**") && line.hasSuffix("**") { line = String(line.dropFirst(2).dropLast(2)) }
            if !line.isEmpty { out.append(line) }
        }
        return out.isEmpty ? fallback : out
    }

    /// Share / copy: one question per line, numbered.
    public static func plainText(_ questions: [String], title: String? = nil) -> String {
        var lines: [String] = []
        if let title, !title.isEmpty { lines.append(title); lines.append("") }
        for (i, q) in questions.enumerated() { lines.append("\(i + 1). \(q)") }
        return lines.joined(separator: "\n")
    }
}
