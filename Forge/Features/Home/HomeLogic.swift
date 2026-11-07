import Foundation
import ForgeCore

/// What a card says about an idea's place on the path (§7 v4.1).
enum IdeaStatus: Equatable {
    case notChecked
    case checking
    case checked(verdict: RealityVerdict, confidence: Int)

    static func of(_ idea: Idea, checking: Bool = false) -> IdeaStatus {
        if checking { return .checking }
        if let check = idea.latestRealityCheck {
            return .checked(verdict: check.verdict, confidence: idea.latestEvaluation?.confidence ?? 0)
        }
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

    /// Priority: the idea just captured; a Brief waiting for review; a step owed
    /// in the Workshop; else the most recent idea nobody has checked.
    static func choose(justCaptured: UUID?, ideas: [Idea], projects: [Project], unseenBriefs: Set<UUID>) -> HomeCard {
        if let id = justCaptured, ideas.contains(where: { $0.id == id && !$0.isArchived }) {
            return .afterCapture(ideaID: id)
        }
        let live = ideas.filter { !$0.isArchived }
        let waiting = live
            .filter { $0.latestRealityCheck != nil && $0.project == nil && (unseenBriefs.contains($0.id) || !$0.hasRuling) }
            .max { ($0.latestRealityCheck?.createdAt ?? .distantPast) < ($1.latestRealityCheck?.createdAt ?? .distantPast) }
        if let waiting { return .briefReady(ideaID: waiting.id) }
        if let owed = projects.filter({ $0.status == .active && $0.nextStep != nil }).max(by: { $0.createdAt < $1.createdAt }) {
            return .nextStep(projectID: owed.id)
        }
        if let fresh = live.filter({ $0.latestRealityCheck == nil && $0.project == nil }).max(by: { $0.createdAt < $1.createdAt }) {
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
