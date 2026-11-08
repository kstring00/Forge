import Foundation
import SwiftData
import ForgeCore

/// Decision 0025: one project per idea. Projects that lost their idea (two
/// projects pointing at one idea, a Looks right tapped twice before the rule,
/// an import) are merged into the idea's newest project when the name
/// matches, re-linked when an idea of the same title has none, and archived
/// otherwise. A project whose idea is archived is archived with it. Runs once
/// at launch; the report stays in Settings so the user can read what it did.
enum ProjectCleanup {
    static let versionKey = "projectCleanup.version"
    static let reportKey = "projectCleanup.report"
    static let version = 1

    struct Report: Codable, Equatable {
        var ranAt = Date()
        /// Projects at the start, and how many had no idea.
        var projects = 0
        var orphans = 0
        var merged = 0
        var relinked = 0
        var archived = 0
        var followedIdea = 0

        var line: String {
            if orphans == 0 && followedIdea == 0 { return "Checked \(projects) \(projects == 1 ? "project" : "projects"): every one belongs to an idea. Nothing changed." }
            var parts: [String] = []
            if merged > 0 { parts.append("merged \(merged) duplicate\(merged == 1 ? "" : "s") into the newest") }
            if relinked > 0 { parts.append("re-linked \(relinked) to \(relinked == 1 ? "its" : "their") idea") }
            if archived > 0 { parts.append("archived \(archived) orphan\(archived == 1 ? "" : "s")") }
            if followedIdea > 0 { parts.append("archived \(followedIdea) whose idea was archived") }
            return "Of \(projects) projects, \(orphans) had no idea: " + parts.joined(separator: ", ") + "."
        }
    }

    @MainActor
    static func runIfNeeded(in context: ModelContext, defaults: UserDefaults = .standard) {
        guard defaults.integer(forKey: versionKey) < version else { return }
        let report = run(in: context)
        defaults.set(version, forKey: versionKey)
        if let data = try? JSONEncoder().encode(report) { defaults.set(data, forKey: reportKey) }
        print("ProjectCleanup: " + report.line)
    }

    static func lastReport(_ defaults: UserDefaults = .standard) -> Report? {
        defaults.data(forKey: reportKey).flatMap { try? JSONDecoder().decode(Report.self, from: $0) }
    }

    @MainActor
    @discardableResult
    static func run(in context: ModelContext) -> Report {
        var report = Report()
        guard let projects = try? context.fetch(FetchDescriptor<Project>()),
              let ideas = try? context.fetch(FetchDescriptor<Idea>()) else { return report }
        report.projects = projects.count
        let orphans = projects.filter { $0.idea == nil && $0.status != .archived }
        report.orphans = orphans.count

        for orphan in orphans.sorted(by: { $0.createdAt < $1.createdAt }) {
            // 1. An idea whose project has this name: the two are one project; the newest stays.
            if let idea = ideas.first(where: { $0.project.map { same($0.name, orphan.name) } ?? false }), let current = idea.project {
                if orphan.createdAt > current.createdAt {
                    idea.project = orphan
                    merge(current, into: orphan, context: context)
                } else {
                    merge(orphan, into: current, context: context)
                }
                report.merged += 1
                continue
            }
            // 2. An idea with the same title and no project: it was this one's.
            if let idea = ideas.first(where: { $0.project == nil && !$0.isArchived && same($0.title, orphan.name) }) {
                idea.project = orphan
                if idea.stage.track != .reality { idea.stage = .build }
                report.relinked += 1
                continue
            }
            // 3. Nothing to attach it to: out of Reality, nothing deleted.
            orphan.status = .archived
            report.archived += 1
        }

        // A project cannot be active while its idea is archived.
        for project in projects where project.idea?.isArchived == true && (project.status == .active || project.status == .paused) {
            project.status = .archived
            report.followedIdea += 1
        }
        try? context.save()
        return report
    }

    private static func same(_ a: String, _ b: String) -> Bool {
        a.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare(b.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
    }

    /// Everything the older project held moves to the one that stays; then it goes.
    private static func merge(_ old: Project, into kept: Project, context: ModelContext) {
        for d in old.decisions { d.project = kept }
        for m in old.milestones { m.project = kept }
        for note in old.notes where !kept.notes.contains(note) { kept.notes.append(note) }
        for r in old.resources where !kept.resources.contains(r) { kept.resources.append(r) }
        if kept.nextStep == nil, let step = old.nextStep {
            kept.nextStep = step
            kept.nextStepCaveat = old.nextStepCaveat
            kept.nextStepTarget = old.nextStepTarget
            kept.nextStepCount = old.nextStepCount
            kept.nextStepDueAt = old.nextStepDueAt
            kept.nextStepMoves = old.nextStepMoves
        } else if let step = old.nextStep, step != kept.nextStep {
            kept.nextStepCount += old.nextStepCount
        }
        if kept.desiredOutcome.isEmpty { kept.desiredOutcome = old.desiredOutcome }
        if kept.launchDefinition.isEmpty { kept.launchDefinition = old.launchDefinition }
        old.idea = nil
        context.delete(old)
    }
}
