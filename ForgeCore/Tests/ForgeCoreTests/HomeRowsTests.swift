import XCTest
@testable import ForgeCore

final class HomeRowsTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    private func idea(_ n: Int, _ track: Track = .idea, worked minutesAgo: Double, _ state: HomeRowState = .notChecked) -> HomeRowIdea {
        HomeRowIdea(id: UUID(uuidString: "00000000-0000-0000-0000-\(String(format: "%012d", n))")!, track: track,
                    workedAt: t0.addingTimeInterval(-minutesAgo * 60), state: state)
    }

    // MARK: Order and the stage filter

    func testTheNextMoveIsFirstThenTheMostRecentlyWorkedOn() {
        let a = idea(1, worked: 50), b = idea(2, worked: 5), c = idea(3, worked: 20)
        XCTAssertEqual(HomeRows.ordered([a, b, c], nextMoveID: a.id).map(\.id), [a.id, b.id, c.id])
        XCTAssertEqual(HomeRows.ordered([a, b, c], nextMoveID: nil).map(\.id), [b.id, c.id, a.id])
        let tie = [idea(7, worked: 5), idea(4, worked: 5)]
        XCTAssertEqual(HomeRows.ordered(tie, nextMoveID: nil).map(\.id), HomeRows.ordered(tie.reversed(), nextMoveID: nil).map(\.id), "a tie has one order")
    }

    func testEightRowsThenSeeAll() {
        let ideas = (1...11).map { idea($0, worked: Double($0)) }
        let list = HomeRows.list(ideas, nextMoveID: ideas[9].id)
        XCTAssertEqual(list.rows.count, 8)
        XCTAssertEqual(list.total, 11)
        XCTAssertTrue(list.hasMore)
        XCTAssertEqual(list.rows.first?.id, ideas[9].id, "the next move is never cut off by the limit")
        XCTAssertFalse(HomeRows.list(Array(ideas.prefix(7)), nextMoveID: nil).hasMore)
    }

    func testAStageFilterLooksAtEveryIdeaNotOnlyTheEightShowing() {
        // Ten recent ideas in Idea, and one old one out in the world that the first eight would never show.
        var ideas = (1...10).map { idea($0, .idea, worked: Double($0)) }
        let old = idea(99, .reality, worked: 9_000, .stepInProgress(done: 1, of: 5))
        ideas.append(old)
        XCTAssertFalse(HomeRows.list(ideas, nextMoveID: nil).rows.contains(old))
        let filtered = HomeRows.list(ideas, nextMoveID: nil, stage: .reality)
        XCTAssertEqual(filtered.rows, [old])
        XCTAssertEqual(filtered.total, 1)
        XCTAssertEqual(HomeRows.list(ideas, nextMoveID: nil, stage: .formation).total, 0)
    }

    func testTappingAStageAgainClearsIt() {
        XCTAssertEqual(HomeRows.toggled(nil, tapped: .formation), .formation)
        XCTAssertEqual(HomeRows.toggled(.formation, tapped: .formation), nil)
        XCTAssertEqual(HomeRows.toggled(.formation, tapped: .reality), .reality)
    }

    // MARK: Which row is open

    func testWithOneIdeaItsRowIsOpen() {
        let only = idea(1, worked: 10)
        XCTAssertEqual(HomeRows.openRow([only], nextMoveID: nil, memory: nil), only.id)
        XCTAssertEqual(HomeRows.openRow([only], nextMoveID: only.id, memory: nil), only.id, "even when it is the next move")
        XCTAssertNil(HomeRows.openRow([], nextMoveID: nil, memory: nil))
    }

    func testTheIdeaLastWorkedOnIsOpenUnlessItIsTheNextMove() {
        let a = idea(1, worked: 50), b = idea(2, worked: 5), c = idea(3, worked: 20)
        XCTAssertEqual(HomeRows.openRow([a, b, c], nextMoveID: a.id, memory: nil), b.id)
        XCTAssertNil(HomeRows.openRow([a, b, c], nextMoveID: b.id, memory: nil), "its card is right above the list")
    }

    func testARowOpenedOrClosedByHandStaysUntilADifferentIdeaIsWorkedOn() {
        let a = idea(1, worked: 50), b = idea(2, worked: 5), c = idea(3, worked: 20)
        let ideas = [a, b, c]
        // b is open by default. The person opens c instead.
        var open = HomeRows.openRow(ideas, nextMoveID: nil, memory: nil)
        var memory = HomeRows.afterTap(c.id, open: open, ideas: ideas)
        open = HomeRows.openRow(ideas, nextMoveID: nil, memory: memory)
        XCTAssertEqual(open, c.id)
        // They close it: nothing is open, and it stays that way on the next launch.
        memory = HomeRows.afterTap(c.id, open: open, ideas: ideas)
        XCTAssertNil(HomeRows.openRow(ideas, nextMoveID: nil, memory: memory))
        XCTAssertNil(HomeRows.openRow(ideas, nextMoveID: nil, memory: HomeOpenRowMemory(raw: memory.raw)))
        // Then they work on a: it becomes the open one.
        var worked = a
        worked.workedAt = t0.addingTimeInterval(60)
        XCTAssertEqual(HomeRows.openRow([worked, b, c], nextMoveID: nil, memory: memory), a.id)
        // Working on the same idea again changes nothing about a choice made since.
        let later = HomeRows.afterTap(c.id, open: a.id, ideas: [worked, b, c])
        var again = worked
        again.workedAt = t0.addingTimeInterval(120)
        XCTAssertEqual(HomeRows.openRow([again, b, c], nextMoveID: nil, memory: later), c.id)
    }

    func testAnOpenedRowThatNoLongerExistsFallsBackToTheRule() {
        let a = idea(1, worked: 50), b = idea(2, worked: 5)
        let gone = HomeOpenRowMemory(opened: UUID(), whenLastWorked: b.id)
        XCTAssertEqual(HomeRows.openRow([a, b], nextMoveID: nil, memory: gone), b.id)
    }

    func testTheMemorySurvivesBeingSaved() {
        let m = HomeOpenRowMemory(opened: UUID(), whenLastWorked: UUID())
        XCTAssertEqual(HomeOpenRowMemory(raw: m.raw), m)
        let closed = HomeOpenRowMemory(opened: nil, whenLastWorked: UUID())
        XCTAssertEqual(HomeOpenRowMemory(raw: closed.raw), closed)
        XCTAssertNil(HomeOpenRowMemory(raw: ""), "nothing saved is no choice")
        XCTAssertNil(HomeOpenRowMemory(raw: "nonsense"))
    }

    // MARK: A status line for every state

    func testEveryStateHasAPlainLine() {
        let lines: [(HomeRowState, String)] = [
            (.notChecked, "Not checked yet"),
            (.checking, "The panel is checking it"),
            (.checkFailed, "The check didn't finish. Try again."),
            (.offline, "No connection. Try the check again later."),
            (.personal, "Judged by what it changes for you"),
            (.takeReady, "The panel's take is ready"),
            (.deciding(answered: 0, of: 5), "Waiting on your decision"),
            (.deciding(answered: 2, of: 5), "You answered 2 of 5 panelists"),
            (.decided, "You heard the panel. Ready for a next step."),
            (.stepInProgress(done: 0, of: 5), "Talked to 0 of 5 people"),
            (.stepInProgress(done: 1, of: 5), "Talked to 1 of 5 people"),
            (.stepInProgress(done: 0, of: 1), "Next step not done yet"),
            (.stepReached(of: 5), "Talked to all 5. Say what happened."),
            (.stepReached(of: 1), "Step done. Say what happened."),
            (.awaitingOutcome, "Waiting to hear what happened"),
            (.noStep, "No next step set"),
            (.paused, "Paused"),
            (.launched, "Launched"),
        ]
        for (state, line) in lines {
            XCTAssertEqual(state.line, line)
            XCTAssertFalse(state.line.contains("Ruled"), "no internal words")
            XCTAssertNotEqual(state.line, state.line.uppercased(), "sentence case, never all caps")
        }
        XCTAssertEqual(HomeRowState.stepInProgress(done: 9, of: 5).line, "Talked to 5 of 5 people", "never more than the target")
    }

    func testTheNextMoveCardSaysWhyAndHowFar() {
        XCTAssertEqual(HomeRowState.stepInProgress(done: 0, of: 5).progress, "0 of 5 conversations")
        XCTAssertEqual(HomeRowState.stepInProgress(done: 2, of: 5).fraction, 0.4)
        XCTAssertEqual(HomeRowState.stepReached(of: 5).fraction, 1)
        XCTAssertNil(HomeRowState.notChecked.progress)
        XCTAssertNil(HomeRowState.stepInProgress(done: 0, of: 1).progress, "a single step has no count")
        for state in [HomeRowState.notChecked, .checkFailed, .offline, .takeReady, .deciding(answered: 1, of: 5),
                      .stepInProgress(done: 0, of: 5), .stepReached(of: 5), .awaitingOutcome, .noStep] {
            XCTAssertNotNil(state.why, "\(state)")
        }
        XCTAssertTrue(HomeRowState.checkFailed.needsAttention)
        XCTAssertTrue(HomeRowState.offline.needsAttention)
        XCTAssertFalse(HomeRowState.notChecked.needsAttention)
    }

    func testVoiceOverReadsARowAsOneItemWithItsState() {
        XCTAssertEqual(HomeRows.spoken(title: "RV park sites", track: .reality, state: .stepInProgress(done: 1, of: 5), isNext: true, isOpen: false),
                       "RV park sites, your next move, Reality stage, Talked to 1 of 5 people, collapsed")
        XCTAssertEqual(HomeRows.spoken(title: "Clinic tags", track: .idea, state: .notChecked, isNext: false, isOpen: true),
                       "Clinic tags, Idea stage, Not checked yet, expanded")
    }

    // MARK: Potential as a word

    func testTheLowestBandReadsUnproven() {
        XCTAssertEqual(PotentialBand.word(4), "Unproven")
        XCTAssertEqual(PotentialBand.word(19), "Unproven")
        XCTAssertEqual(PotentialBand.word(20), "Modest")
        XCTAssertEqual(PotentialBand.word(45), "Promising")
        XCTAssertEqual(PotentialBand.word(79), "Strong")
        XCTAssertEqual(PotentialBand.word(80), "Big")
        XCTAssertEqual(PotentialBand.full(4), "4 of 100 · Unproven")
        XCTAssertEqual(PotentialBand.full(140), "100 of 100 · Big")
    }
}
