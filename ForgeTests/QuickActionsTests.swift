import XCTest
import UIKit
@testable import Forge

/// Decisions 0025 and 0026: every way in from outside lands in one place and
/// is taken exactly once.
@MainActor
final class QuickActionsTests: XCTestCase {
    func testShortcutItemsAndIntentsAreTakenOnce() {
        let q = QuickActions.shared
        _ = q.take()
        XCTAssertTrue(q.receive(UIApplicationShortcutItem(type: "app.forge.newIdea", localizedTitle: "New idea")))
        XCTAssertEqual(q.take(), .newIdea)
        XCTAssertNil(q.take(), "taken once")
        XCTAssertFalse(q.receive(UIApplicationShortcutItem(type: "something.else", localizedTitle: "?")))
        q.request(.newHunch)
        XCTAssertEqual(q.take(), .newHunch)
    }
}
