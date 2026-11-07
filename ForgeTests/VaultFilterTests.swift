import XCTest
import SwiftData
import ForgeCore
@testable import Forge

@MainActor
final class VaultFilterTests: XCTestCase {
    private var store: TestStore!
    private var context: ModelContext!
    private var a: Idea!
    private var b: Idea!
    private var c: Idea!
    private var archived: Idea!

    override func setUp() async throws {
        store = try TestStore()
        context = store.context
        let a = Idea(originalText: "A newsletter for horse boarding barns")
        a.tags = ["Email", "equine"]
        a.lensType = .business
        let b = Idea(originalText: "Learn to draw horses every morning")
        b.lensType = .growth
        b.stage = .explore
        let c = Idea(originalText: "A marina booking tool")
        c.lensType = .business
        c.tags = ["email"]
        let archived = Idea(originalText: "An old thought about boats")
        archived.archive()
        for idea in [a, b, c, archived] { context.insert(idea) }
        // Deterministic order: a oldest, c newest; a most recently updated.
        a.createdAt = Date(timeIntervalSince1970: 1_000)
        b.createdAt = Date(timeIntervalSince1970: 2_000)
        c.createdAt = Date(timeIntervalSince1970: 3_000)
        a.updatedAt = Date(timeIntervalSince1970: 9_000)
        b.updatedAt = Date(timeIntervalSince1970: 5_000)
        c.updatedAt = Date(timeIntervalSince1970: 4_000)
        try context.save()
        self.a = a; self.b = b; self.c = c; self.archived = archived
    }

    private var all: [Idea] { [a, b, c, archived].compactMap { $0 } }

    func testDefaultHidesArchivedAndSortsNewestFirst() {
        let shown = VaultFilter().apply(to: all)
        XCTAssertEqual(shown.map(\.id), [c.id, b.id, a.id])
    }

    func testShowArchivedShowsOnlyArchived() {
        var f = VaultFilter()
        f.showArchived = true
        XCTAssertEqual(f.apply(to: all).map(\.id), [archived.id])
    }

    func testSearchMatchesEveryTermAcrossFields() {
        var f = VaultFilter()
        f.searchText = "horse"
        XCTAssertEqual(Set(f.apply(to: all).map(\.id)), [a.id, b.id])
        f.searchText = "horse morning"
        XCTAssertEqual(f.apply(to: all).map(\.id), [b.id])
        f.searchText = "EQUINE"
        XCTAssertEqual(f.apply(to: all).map(\.id), [a.id])
        f.searchText = "boats"
        XCTAssertTrue(f.apply(to: all).isEmpty, "archived ideas stay hidden even when they match")
    }

    func testLensStageAndTagFilters() {
        var f = VaultFilter()
        f.lens = .business
        XCTAssertEqual(Set(f.apply(to: all).map(\.id)), [a.id, c.id])
        f.lens = nil
        f.stage = .explore
        XCTAssertEqual(f.apply(to: all).map(\.id), [b.id])
        f.stage = nil
        f.tag = "EMAIL"
        XCTAssertEqual(Set(f.apply(to: all).map(\.id)), [a.id, c.id], "tag filter is case-insensitive")
    }

    func testScoreSortRequiresALens() throws {
        var f = VaultFilter()
        f.sort = .potential
        XCTAssertEqual(f.effectiveSort, .updated, "no lens: fall back to updated, never rank across lenses")
        XCTAssertEqual(f.apply(to: all).map(\.id), [a.id, b.id, c.id])

        f.lens = .business
        XCTAssertEqual(f.effectiveSort, .potential)
        let e = c.beginEvaluation(lens: .business)
        for crit in Lenses.business.criteria { try e.set(key: crit.key, score: 4, evidenceLevel: 2) }
        XCTAssertEqual(f.apply(to: all).map(\.id), [c.id, a.id], "evaluated idea first, unevaluated after")
    }

    func testUpdatedSort() {
        var f = VaultFilter()
        f.sort = .updated
        XCTAssertEqual(f.apply(to: all).map(\.id), [a.id, b.id, c.id])
    }

    func testAllTagsDeduplicatesCaseInsensitively() {
        XCTAssertEqual(VaultFilter.allTags(in: all), ["Email", "equine"])
    }

    func testParseTags() {
        XCTAssertEqual(Idea.parseTags(" one, Two ,two, ,three\nfour "), ["one", "Two", "three", "four"])
        XCTAssertEqual(Idea.parseTags(""), [])
    }

    func testArchiveAndUnarchiveKeepOriginal() {
        let text = a.originalText
        a.archive()
        XCTAssertTrue(a.isArchived)
        XCTAssertEqual(a.stage, .archived)
        a.unarchive()
        XCTAssertFalse(a.isArchived)
        XCTAssertEqual(a.stage, .capture)
        XCTAssertEqual(a.originalText, text)
    }
}
