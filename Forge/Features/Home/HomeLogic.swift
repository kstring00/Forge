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

extension Idea {
    /// Where the idea sits on screen. A project puts it in Reality whatever the
    /// stored stage says, so the strip, the sections and the tabs agree.
    var track: Track? {
        if isArchived { return nil }
        if project != nil { return .reality }
        return stage.track
    }
}
