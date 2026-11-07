import Foundation
import Observation
import SwiftData
import ForgeCore

/// App-level home for Reality Checks, so Home can show the orbs working after
/// the user leaves the idea, and the Home tab can say a Brief is ready.
@Observable
@MainActor
final class RealityCheckCenter {
    private(set) var runners: [UUID: RealityCheckRunner] = [:]
    /// Ideas whose Brief finished and has not been opened since.
    private(set) var unseenBriefs: Set<UUID> = []
    /// The idea most recently started, for the panel on Home.
    private(set) var focusIdeaID: UUID?

    let proxy: ProxyAIClient?

    init(proxy: ProxyAIClient?) {
        self.proxy = proxy
    }

    var isConfigured: Bool { proxy != nil }

    func runner(for ideaID: UUID) -> RealityCheckRunner {
        if let r = runners[ideaID] { return r }
        let r = RealityCheckRunner(proxy: proxy)
        runners[ideaID] = r
        return r
    }

    func phase(for ideaID: UUID) -> RealityCheckRunner.Phase {
        runners[ideaID]?.phase ?? .idle
    }

    func isRunning(_ ideaID: UUID) -> Bool {
        runners[ideaID]?.isRunning ?? false
    }

    var activeRun: (ideaID: UUID, runner: RealityCheckRunner)? {
        if let id = focusIdeaID, let r = runners[id], r.isRunning { return (id, r) }
        return runners.first { $0.value.isRunning }.map { ($0.key, $0.value) }
    }

    /// Starts a check and keeps it running regardless of which screen is open.
    func start(idea: Idea, context: ModelContext, advantages: [String], constraints: [String]) {
        let ideaID = idea.id
        let r = runner(for: ideaID)
        guard !r.isRunning else { return }
        focusIdeaID = ideaID
        Task { @MainActor [weak self] in
            await r.run(on: idea, in: context, advantages: advantages, constraints: constraints)
            if case .done = r.phase { self?.unseenBriefs.insert(ideaID) }
        }
    }

    func markSeen(_ ideaID: UUID) {
        unseenBriefs.remove(ideaID)
        if case .done = runners[ideaID]?.phase { runners[ideaID]?.reset() }
    }

    // MARK: Narration (§7): one line per Sphere as it starts, tied to its orb.

    /// Which Spheres are currently working and what each is doing.
    static func narration(for phase: RealityCheckRunner.Phase, lit: Set<Sphere>) -> [(Sphere, String)] {
        switch phase {
        case .researching(let turn, _):
            let active: [Sphere] = turn == 1 ? [.customer] : [.customer, .investor]
            return active.map { ($0, Spheres.profile(for: $0).workingLine) }
        case .prefilling, .applying:
            let next = Sphere.phase3Panel.first { !lit.contains($0) }
            return (next.map { [$0] } ?? []).map { ($0, Spheres.profile(for: $0).workingLine) }
        default:
            return []
        }
    }

    /// Orbs that should render as working (brighter, faster) for a phase.
    static func working(for phase: RealityCheckRunner.Phase, lit: Set<Sphere>) -> Set<Sphere> {
        switch phase {
        case .researching(let turn, _): return turn == 1 ? [.customer] : [.customer, .investor]
        case .prefilling, .applying: return Set(Sphere.phase3Panel).subtracting(lit)
        default: return []
        }
    }
}
