import Foundation

/// The optional, dismissible prompt on Home. One at a time, never nagging.
public enum ReflectivePrompts {
    public static let all: [String] = [
        "Which idea have you been avoiding evaluating, and why?",
        "What did someone complain about this week that you could not stop thinking about?",
        "Is there an idea in the Vault you already know the answer to?",
        "What would the smallest version of your current project look like if it had to ship Friday?",
        "Which assumption are you most attached to right now?",
        "What have you learned this month that changes an old idea?",
        "Is the thing you are working on the thing you would choose again today?",
        "Who did you talk to this week about their problem, not your idea?"
    ]

    /// Deterministic pick for a given day so the prompt is stable across launches.
    public static func prompt(for date: Date = .now, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
