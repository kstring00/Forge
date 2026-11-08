import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Decision 0025: one project per idea. Duplicates merge into the newest,
/// a lost project finds its idea by title, the rest are archived, and an
/// archived idea takes its project out of Reality.
@MainActor
final class ProjectCleanupTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    func testDuplicatesMergeIntoTheNewest() throws {
        let idea = Idea(originalText: "Web care for RV parks")
        store.context.insert(idea)
        let older = WorkshopActions.convert(idea, with: .init(name: "RV park sites", desiredOutcome: "", nextStep: "Talk to five owners"), in: store.context)
        older.createdAt = Date(timeIntervalSinceNow: -7200)
        older.nextStepCount = 2
        older.notes = ["older note"]
        // A second "Looks right" before the rule: the same name, newer, and it took the idea.
        let newer = Project(name: "RV park sites")
        newer.nextStep = "Talk to five owners"
        newer.nextStepCount = 1
        store.context.insert(newer)
        idea.project = newer
        older.idea = nil   // however it came to be, the older project has no idea now
        try store.context.save()

        let report = ProjectCleanup.run(in: store.context)

        XCTAssertEqual(report.merged, 1)
        XCTAssertEqual(idea.project?.id, newer.id, "the newest stays")
        XCTAssertEqual(newer.nextStepCount, 3, "logged conversations from both count")
        XCTAssertTrue(newer.notes.contains("older note"))
        XCTAssertEqual(try store.context.fetch(FetchDescriptor<Project>()).count, 1, "the duplicate is gone")
        XCTAssertEqual(newer.decisions.count, 1, "the commit decision moved over")
    }

    func testOrphansRelinkByTitleOrAreArchived() throws {
        let idea = Idea(originalText: "Fishing charter booking page", title: "Charter bookings")
        store.context.insert(idea)
        let lost = Project(name: "Charter bookings")
        store.context.insert(lost)
        let stray = Project(name: "Something else entirely")
        store.context.insert(stray)
        try store.context.save()

        let report = ProjectCleanup.run(in: store.context)

        XCTAssertEqual(report.relinked, 1)
        XCTAssertEqual(idea.project?.id, lost.id)
        XCTAssertEqual(idea.track, .reality)
        XCTAssertEqual(report.archived, 1)
        XCTAssertEqual(stray.status, .archived)
        XCTAssertEqual(report.orphans, 2)
        XCTAssertFalse(report.line.isEmpty)
    }

    func testArchivingAnIdeaArchivesItsProject() throws {
        let idea = Idea(originalText: "Horse boarding directory")
        store.context.insert(idea)
        let project = WorkshopActions.convert(idea, with: .init(name: "Boarding", desiredOutcome: "", nextStep: "call"), in: store.context)
        idea.archive()
        XCTAssertEqual(project.status, .archived)
        XCTAssertNil(idea.track)
        XCTAssertEqual(TrackCounts.count(.reality, in: [idea]), 0)
    }

    func testConvertNeverMakesASecondProject() throws {
        let idea = Idea(originalText: "Marina wifi")
        store.context.insert(idea)
        let first = WorkshopActions.convert(idea, with: .init(name: "A", desiredOutcome: "", nextStep: "x"), in: store.context)
        let second = WorkshopActions.convert(idea, with: .init(name: "B", desiredOutcome: "", nextStep: "y"), in: store.context)
        XCTAssertEqual(first.id, second.id)
    }
}
