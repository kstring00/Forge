import XCTest
import SwiftData
import ForgeCore
@testable import Forge

@MainActor
final class HomeLogicTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    private func idea(_ text: String, at: TimeInterval) -> Idea {
        let i = Idea(originalText: text)
        i.createdAt = Date(timeIntervalSince1970: at)
        store.context.insert(i)
        return i
    }

    private func check(_ i: Idea, verdict: RealityVerdict = .compete, at: TimeInterval) {
        let rc = RealityCheck(verdict: verdict)
        rc.createdAt = Date(timeIntervalSince1970: at)
        i.realityChecks.append(rc)
    }

    func testIdeaStatus() {
        let a = idea("a", at: 1)
        XCTAssertEqual(IdeaStatus.of(a), .notChecked)
        XCTAssertEqual(IdeaStatus.of(a, checking: true), .checking)
        check(a, verdict: .useTheirs, at: 2)
        let e = a.beginEvaluation(lens: .business)
        try? e.set(key: "A1", score: 3, evidenceLevel: 2)
        XCTAssertEqual(IdeaStatus.of(a), .checked(verdict: .useTheirs, confidence: e.confidence))
    }

    func testJustCapturedWinsOverEverything() {
        let a = idea("a", at: 1); check(a, at: 2)
        let b = idea("b", at: 3)
        XCTAssertEqual(HomeCard.choose(justCaptured: b.id, ideas: [b, a], projects: [], unseenBriefs: [a.id]), .afterCapture(ideaID: b.id))
    }

    func testBriefWaitingBeatsNextStepAndUnchecked() throws {
        let a = idea("checked, unruled", at: 1); check(a, at: 5)
        let b = idea("unchecked", at: 2)
        let c = idea("with project", at: 3)
        let p = WorkshopActions.convert(c, with: .init(name: "P", desiredOutcome: "", nextStep: "call"), in: store.context)
        XCTAssertEqual(HomeCard.choose(justCaptured: nil, ideas: [c, b, a], projects: [p], unseenBriefs: []), .briefReady(ideaID: a.id))

        // Ruling on it (Looks right) clears it, unless the center still marks it unseen.
        let d = Decision(kind: .ruling, decision: "Accepted")
        d.idea = a
        d.date = Date(timeIntervalSince1970: 6)
        store.context.insert(d)
        XCTAssertTrue(a.hasRuling)
        XCTAssertEqual(HomeCard.choose(justCaptured: nil, ideas: [c, b, a], projects: [p], unseenBriefs: []), .nextStep(projectID: p.id))
        XCTAssertEqual(HomeCard.choose(justCaptured: nil, ideas: [c, b, a], projects: [p], unseenBriefs: [a.id]), .briefReady(ideaID: a.id))
    }

    func testUncheckedIsTheLastResortAndNewestFirst() throws {
        let old = idea("old", at: 1)
        let new = idea("new", at: 2)
        XCTAssertEqual(HomeCard.choose(justCaptured: nil, ideas: [new, old], projects: [], unseenBriefs: []), .unchecked(ideaID: new.id))
        new.archive()
        XCTAssertEqual(HomeCard.choose(justCaptured: nil, ideas: [new, old], projects: [], unseenBriefs: []), .unchecked(ideaID: old.id))
        old.archive()
        XCTAssertEqual(HomeCard.choose(justCaptured: nil, ideas: [new, old], projects: [], unseenBriefs: []), .none)
    }

    func testNarrationFollowsThePhases() {
        XCTAssertEqual(RealityCheckCenter.narration(for: .idle, lit: []).count, 0)
        let r1 = RealityCheckCenter.narration(for: .researching(turn: 1, sources: 0), lit: [])
        XCTAssertEqual(r1.map(\.0), [.customer])
        XCTAssertEqual(r1.first?.1, "Reading what people complain about.")
        XCTAssertEqual(RealityCheckCenter.narration(for: .researching(turn: 2, sources: 3), lit: []).map(\.0), [.customer, .investor])
        XCTAssertEqual(RealityCheckCenter.narration(for: .prefilling, lit: []).map(\.0), [.investor])
        XCTAssertEqual(RealityCheckCenter.narration(for: .prefilling, lit: [.investor, .customer]).map(\.0), [.builder])
        XCTAssertEqual(RealityCheckCenter.working(for: .prefilling, lit: [.investor]), Set(Sphere.phase3Panel).subtracting([.investor]))
        XCTAssertTrue(RealityCheckCenter.narration(for: .done, lit: Set(Sphere.phase3Panel)).isEmpty)
    }

    func testCenterTracksUnseenBriefs() {
        let center = RealityCheckCenter(proxy: nil)
        let id = UUID()
        XCTAssertFalse(center.isConfigured)
        XCTAssertEqual(center.phase(for: id), .idle)
        _ = center.runner(for: id)
        XCTAssertFalse(center.isRunning(id))
        center.markSeen(id)
        XCTAssertTrue(center.unseenBriefs.isEmpty)
    }
}
