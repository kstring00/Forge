import Foundation

/// Home usability pass, part (b), decision 0044: Home's list as plain values,
/// so the order, the stage filter, the status line for every state and which
/// row is open are decided here and tested, not in a view.

/// Where an idea stands, as far as its row on Home is concerned.
public enum HomeRowState: Equatable, Sendable {
    /// Nobody has looked at it yet.
    case notChecked
    /// The panel is working on it now.
    case checking
    /// The last check stopped before it finished.
    case checkFailed
    /// The last check could not reach the internet.
    case offline
    /// A Growth or Creative idea: judged by what it changes, never checked.
    case personal
    /// The panel has answered and the person hasn't opened it.
    case takeReady
    /// The person is going through the panel: `answered` of `of` voices.
    case deciding(answered: Int, of: Int)
    /// Every voice answered; nothing started in the world yet.
    case decided
    /// A step in the world: `done` of `of` conversations logged.
    case stepInProgress(done: Int, of: Int)
    /// The step reached its target and waits for what happened.
    case stepReached(of: Int)
    /// A commitment was made and has no outcome yet.
    case awaitingOutcome
    /// Out in the world with no step set.
    case noStep
    case paused
    case launched

    /// The one plain line under the title.
    public var line: String {
        switch self {
        case .notChecked: "Not checked yet"
        case .checking: "The panel is checking it"
        case .checkFailed: "The check didn't finish. Try again."
        case .offline: "No connection. Try the check again later."
        case .personal: "Judged by what it changes for you"
        case .takeReady: "The panel's take is ready"
        case .deciding(let answered, let of):
            answered <= 0 || of <= 0 ? "Waiting on your decision" : "You answered \(min(answered, of)) of \(of) panelists"
        case .decided: "You heard the panel. Ready for a next step."
        case .stepInProgress(let done, let of):
            of <= 1 ? "Next step not done yet" : "Talked to \(min(max(done, 0), of)) of \(of) people"
        case .stepReached(let of):
            of <= 1 ? "Step done. Say what happened." : "Talked to all \(of). Say what happened."
        case .awaitingOutcome: "Waiting to hear what happened"
        case .noStep: "No next step set"
        case .paused: "Paused"
        case .launched: "Launched"
        }
    }

    /// Why this is the next move, in one line, for the "Your next move" card.
    /// Nil for states that are never the next move.
    public var why: String? {
        switch self {
        case .notChecked: "It hasn't been checked yet. The panel looks it up and tells you where it stands."
        case .checking: "The panel is on it. This takes a minute or two."
        case .checkFailed: "The last check didn't finish. Give it another go."
        case .offline: "The last check couldn't get online. Try again when you're connected."
        case .takeReady, .deciding: "The panel has answered. Hear what each one said, then decide."
        case .stepInProgress: "Real conversations are the proof. Each one you log moves this idea forward."
        case .stepReached: "You hit your target. Say what happened so it counts as proof."
        case .awaitingOutcome: "You set this in motion. Say how it went."
        case .noStep: "It's out in the world with nothing to do next. Pick one small step."
        case .personal, .decided, .paused, .launched: nil
        }
    }

    /// "1 of 5 conversations", when the state has a count.
    public var progress: String? {
        switch self {
        case .stepInProgress(let done, let of) where of > 1: "\(min(max(done, 0), of)) of \(of) conversations"
        case .stepReached(let of) where of > 1: "\(of) of \(of) conversations"
        case .deciding(let answered, let of) where of > 0: "\(min(max(answered, 0), of)) of \(of) panelists answered"
        default: nil
        }
    }

    /// 0 to 1 for a progress bar, when the state has a count.
    public var fraction: Double? {
        switch self {
        case .stepInProgress(let done, let of) where of > 1: Double(min(max(done, 0), of)) / Double(of)
        case .stepReached(let of) where of > 1: 1
        case .deciding(let answered, let of) where of > 0: Double(min(max(answered, 0), of)) / Double(of)
        default: nil
        }
    }

    /// Something is wrong and the row should show a warning mark (never colour alone).
    public var needsAttention: Bool { self == .checkFailed || self == .offline }
    public var isWorking: Bool { self == .checking }
}

/// One idea, as its row needs it.
public struct HomeRowIdea: Equatable, Sendable, Identifiable {
    public var id: UUID
    public var track: Track
    /// When the person last worked on it.
    public var workedAt: Date
    public var state: HomeRowState

    public init(id: UUID, track: Track, workedAt: Date, state: HomeRowState) {
        self.id = id
        self.track = track
        self.workedAt = workedAt
        self.state = state
    }
}

/// A row the person opened or closed by hand, and which idea was the last
/// worked on at that moment. It holds until they work on a different idea.
public struct HomeOpenRowMemory: Equatable, Sendable {
    /// The row opened by hand; nil means they closed the open row.
    public var opened: UUID?
    public var whenLastWorked: UUID?

    public init(opened: UUID?, whenLastWorked: UUID?) {
        self.opened = opened
        self.whenLastWorked = whenLastWorked
    }

    /// Saved as one short string: "<opened or ->|<last worked or ->". Empty is "no choice made".
    public init?(raw: String) {
        let parts = raw.split(separator: "|", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return nil }
        opened = UUID(uuidString: String(parts[0]))
        whenLastWorked = UUID(uuidString: String(parts[1]))
    }

    public var raw: String { "\(opened?.uuidString ?? "-")|\(whenLastWorked?.uuidString ?? "-")" }
}

public enum HomeRows {
    /// How many rows Home shows before "See all".
    public static let limit = 8

    public struct List: Equatable, Sendable {
        public var rows: [HomeRowIdea]
        /// How many ideas match (all of them, or all in the chosen stage).
        public var total: Int
        public var hasMore: Bool { total > rows.count }
    }

    /// The next-move idea first, then the most recently worked on.
    public static func ordered(_ ideas: [HomeRowIdea], nextMoveID: UUID?) -> [HomeRowIdea] {
        ideas.sorted { a, b in
            if (a.id == nextMoveID) != (b.id == nextMoveID) { return a.id == nextMoveID }
            if a.workedAt != b.workedAt { return a.workedAt > b.workedAt }
            return a.id.uuidString < b.id.uuidString
        }
    }

    /// Home's list: every idea, or every idea in one stage, in order, cut to
    /// `limit`. The stage filter looks at all ideas, not only the ones showing.
    public static func list(_ ideas: [HomeRowIdea], nextMoveID: UUID?, stage: Track? = nil, limit: Int = limit) -> List {
        let matching = stage.map { s in ideas.filter { $0.track == s } } ?? ideas
        return List(rows: Array(ordered(matching, nextMoveID: nextMoveID).prefix(max(0, limit))), total: matching.count)
    }

    /// Tapping a stage filters to it; tapping it again clears the filter.
    public static func toggled(_ current: Track?, tapped: Track) -> Track? { current == tapped ? nil : tapped }

    /// The idea last worked on, across all ideas.
    public static func lastWorked(_ ideas: [HomeRowIdea]) -> UUID? {
        ideas.max { a, b in a.workedAt != b.workedAt ? a.workedAt < b.workedAt : a.id.uuidString > b.id.uuidString }?.id
    }

    /// Which row is open. One at most.
    /// - A row the person opened or closed by hand stays that way until they
    ///   work on a different idea.
    /// - Otherwise: with one idea, that idea; else the idea last worked on,
    ///   unless it is the next move (its card is right above), then none.
    public static func openRow(_ ideas: [HomeRowIdea], nextMoveID: UUID?, memory: HomeOpenRowMemory?) -> UUID? {
        guard !ideas.isEmpty else { return nil }
        let last = lastWorked(ideas)
        if let memory, memory.whenLastWorked == last {
            guard let opened = memory.opened else { return nil }
            if ideas.contains(where: { $0.id == opened }) { return opened }
        }
        if ideas.count == 1 { return ideas[0].id }
        return last == nextMoveID ? nil : last
    }

    /// What to remember after the person taps a row: tapping the open row closes it.
    public static func afterTap(_ id: UUID, open: UUID?, ideas: [HomeRowIdea]) -> HomeOpenRowMemory {
        HomeOpenRowMemory(opened: open == id ? nil : id, whenLastWorked: lastWorked(ideas))
    }

    /// What VoiceOver says for a row, as one item.
    public static func spoken(title: String, track: Track, state: HomeRowState, isNext: Bool, isOpen: Bool) -> String {
        var parts = [title]
        if isNext { parts.append("your next move") }
        parts.append("\(track.displayName) stage")
        parts.append(state.line)
        parts.append(isOpen ? "expanded" : "collapsed")
        return parts.joined(separator: ", ")
    }
}

/// Potential as a word. On Home the word shows without the number; the Brief
/// shows "4 of 100" with the word.
public enum PotentialBand {
    /// The lowest band reads "Unproven" (decided Nov 10; temporary, until
    /// Potential itself is steadier). It was "Long shot".
    public static func word(_ potential: Int) -> String {
        switch potential {
        case ..<20: "Unproven"
        case ..<40: "Modest"
        case ..<60: "Promising"
        case ..<80: "Strong"
        default: "Big"
        }
    }

    /// "4 of 100 · Unproven", for the Brief and VoiceOver.
    public static func full(_ potential: Int) -> String {
        "\(min(max(potential, 0), 100)) of 100 · \(word(potential))"
    }
}
