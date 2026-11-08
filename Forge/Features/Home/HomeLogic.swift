import Foundation
import ForgeCore

/// What a card says about an idea's place on the path (§7 v4.1).
enum IdeaStatus: Equatable {
    case notChecked
    case checking
    /// The last run failed; the card says so instead of "Not yet checked".
    case checkFailed
    case checked(verdict: RealityVerdict, confidence: Int)
    /// Growth and Creative ideas: no Reality Check, the Impact card instead.
    case impact

    static func of(_ idea: Idea, checking: Bool = false, failed: Bool = false) -> IdeaStatus {
        if checking { return .checking }
        if let check = idea.latestRealityCheck {
            return .checked(verdict: check.verdict, confidence: idea.latestEvaluation?.confidence ?? 0)
        }
        if !RealityCheckPolicy.isOffered(for: idea.lensType) { return .impact }
        if failed { return .checkFailed }
        return .notChecked
    }
}

/// The one card Home shows: whichever is most urgent.
enum HomeCard: Equatable {
    case afterCapture(ideaID: UUID)
    case briefReady(ideaID: UUID)
    case nextStep(projectID: UUID)
    case unchecked(ideaID: UUID)
    case none

    /// Priority: the idea just captured; a check that failed (its card carries
    /// the error); the step owed in Reality; a Brief waiting to be heard; else
    /// the most recent idea nobody has checked. A real-world step always
    /// outranks a ruling. Only Business ideas (or ideas with no lens yet) are
    /// offered a check.
    static func choose(justCaptured: UUID?, ideas: [Idea], projects: [Project], unseenBriefs: Set<UUID>, failedChecks: Set<UUID> = []) -> HomeCard {
        if let id = justCaptured, ideas.contains(where: { $0.id == id && !$0.isArchived }) {
            return .afterCapture(ideaID: id)
        }
        let live = ideas.filter { !$0.isArchived }
        let checkable = live.filter { $0.latestRealityCheck == nil && $0.project == nil && RealityCheckPolicy.isOffered(for: $0.lensType) }
        if let failed = checkable.filter({ failedChecks.contains($0.id) }).max(by: { $0.createdAt < $1.createdAt }) {
            return .unchecked(ideaID: failed.id)
        }
        if let owed = projects.filter({ $0.status == .active && $0.nextStep != nil }).max(by: { $0.createdAt < $1.createdAt }) {
            return .nextStep(projectID: owed.id)
        }
        let waiting = live
            .filter { $0.latestRealityCheck != nil && $0.project == nil && (unseenBriefs.contains($0.id) || !$0.hasRuling) }
            .max { ($0.latestRealityCheck?.createdAt ?? .distantPast) < ($1.latestRealityCheck?.createdAt ?? .distantPast) }
        if let waiting { return .briefReady(ideaID: waiting.id) }
        if let fresh = checkable.max(by: { $0.createdAt < $1.createdAt }) {
            return .unchecked(ideaID: fresh.id)
        }
        return .none
    }
}

extension Idea {
    /// The user has ruled on the latest check (Looks right writes a ruling Decision).
    var hasRuling: Bool {
        guard let check = latestRealityCheck else { return false }
        return decisions.contains { $0.kind == .ruling && $0.date >= check.createdAt }
    }
}

/// Home's "Your ideas" order (decision 0025). Biggest opportunity is the default.
enum HomeSort: String, CaseIterable, Identifiable {
    case biggestOpportunity, newest, needsThePanel, inProgress

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .biggestOpportunity: "Biggest opportunity"
        case .newest: "Newest"
        case .needsThePanel: "Needs the panel"
        case .inProgress: "In progress"
        }
    }

    /// The muted line under "Your ideas".
    var subline: String {
        switch self {
        case .biggestOpportunity: "Biggest opportunity first"
        case .newest: "Newest first"
        case .needsThePanel: "Ideas the panel hasn't seen, first"
        case .inProgress: "Ideas with a step in the world, first"
        }
    }

    static func sorted(_ ideas: [Idea], by sort: HomeSort) -> [Idea] {
        switch sort {
        case .biggestOpportunity:
            return ideas.sorted { a, b in
                let ma = EstimatedReturn.sortKey(for: a), mb = EstimatedReturn.sortKey(for: b)
                if (ma ?? -1) != (mb ?? -1) { return (ma ?? -1) > (mb ?? -1) }
                let ca = a.latestEvaluation?.confidence ?? -1, cb = b.latestEvaluation?.confidence ?? -1
                if ca != cb { return ca > cb }
                return a.updatedAt > b.updatedAt
            }
        case .newest:
            return ideas.sorted { $0.createdAt > $1.createdAt }
        case .needsThePanel:
            func rank(_ i: Idea) -> Int { i.latestRealityCheck == nil && RealityCheckPolicy.isOffered(for: i.lensType) ? 0 : 1 }
            return ideas.sorted { (rank($0), $1.createdAt) < (rank($1), $0.createdAt) }
        case .inProgress:
            func rank(_ i: Idea) -> Int {
                if let p = i.project, p.status == .active { return 0 }
                if i.track == .reality { return 1 }
                if i.track == .formation { return 2 }
                return 3
            }
            return ideas.sorted { (rank($0), $1.updatedAt) < (rank($1), $0.updatedAt) }
        }
    }
}

/// Decision 0025: the one place ideas are counted and grouped by track. The
/// pipeline nodes, Home's subline, the Ideas sections and Settings all read
/// from here, so a count always matches the list behind it.
enum TrackCounts {
    /// Ideas that are not archived, in the order given.
    static func live(_ ideas: [Idea]) -> [Idea] { ideas.filter { !$0.isArchived } }

    /// Live ideas by track, in the order given. Every track has a key.
    static func grouped(_ ideas: [Idea]) -> [Track: [Idea]] {
        var out: [Track: [Idea]] = Dictionary(uniqueKeysWithValues: Track.allCases.map { ($0, []) })
        for idea in live(ideas) { if let t = idea.track { out[t, default: []].append(idea) } }
        return out
    }

    static func count(_ track: Track, in ideas: [Idea]) -> Int { grouped(ideas)[track]?.count ?? 0 }

    /// Idea, Formation, Reality, in `Track.allCases` order.
    static func counts(_ ideas: [Idea]) -> [Int] {
        let g = grouped(ideas)
        return Track.allCases.map { g[$0]?.count ?? 0 }
    }
}

extension Idea {
    /// Where the idea sits on screen. A project puts it in Reality whatever the
    /// stored stage says, so the strip, the sections and the tabs agree.
    var track: Track? {
        if isArchived { return nil }
        if project != nil { return .reality }
        return stage.track
    }
}
