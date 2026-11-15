import XCTest
import ForgeCore
@testable import Forge

/// Decision 0028: the welcome shows once, the free check is offered until a
/// check has come back, the guide's callouts stay dismissed, and a replay
/// touches none of it.
@MainActor
final class FirstRunTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        defaults = UserDefaults(suiteName: "FirstRunTests-\(UUID().uuidString)")
    }

    func testWelcomeOnceAndFreeCheckUntilAnyCheck() {
        let f = FirstRun(defaults: defaults)
        XCTAssertTrue(f.showsWelcome(ideasEmpty: true))
        XCTAssertFalse(f.showsWelcome(ideasEmpty: false), "an existing vault never sees the welcome")
        f.markWelcomeSeen()
        XCTAssertFalse(f.showsWelcome(ideasEmpty: true))
        XCTAssertFalse(FirstRun(defaults: defaults).showsWelcome(ideasEmpty: true), "persisted")
        XCTAssertTrue(f.offersFirstCheck(hasAnyCheck: false))
        XCTAssertFalse(f.offersFirstCheck(hasAnyCheck: true))
    }

    func testGuideCalloutsStayDismissed() {
        let f = FirstRun(defaults: defaults)
        XCTAssertTrue(f.showsGuide(.orbs))
        f.dismiss(.orbs)
        XCTAssertFalse(f.showsGuide(.orbs))
        XCTAssertTrue(f.showsGuide(.verdict))
        XCTAssertFalse(FirstRun(defaults: defaults).showsGuide(.orbs), "persisted")
        f.dismiss(.verdict); f.dismiss(.nextStep)
        XCTAssertTrue(f.guideDismissed)
    }

    func testReplayShowsEverythingAndLeavesTheFlagsAlone() {
        let f = FirstRun(defaults: defaults)
        f.markWelcomeSeen()
        for s in FirstRun.GuideStep.allCases { f.dismiss(s) }
        f.startReplay()
        XCTAssertTrue(f.showsWelcome(ideasEmpty: false))
        XCTAssertTrue(f.offersFirstCheck(hasAnyCheck: true))
        XCTAssertTrue(f.showsGuide(.verdict))
        f.markWelcomeSeen()
        XCTAssertFalse(f.showsWelcome(ideasEmpty: false), "leaving the welcome during a replay never traps you on it")
        f.dismiss(.verdict); f.dismiss(.orbs)
        XCTAssertTrue(f.replaying)
        f.dismiss(.nextStep)
        XCTAssertFalse(f.replaying, "the last callout ends the replay")
        XCTAssertTrue(f.welcomeSeen)
        XCTAssertTrue(f.guideDismissed, "real flags untouched")
        XCTAssertFalse(f.showsWelcome(ideasEmpty: true))
    }

    func testTheExamplePassesTheGuard() {
        XCTAssertEqual(IdeaGuard.check(ExampleIdea.text), .ok, "the example must never be blocked before the free check")
    }
}
