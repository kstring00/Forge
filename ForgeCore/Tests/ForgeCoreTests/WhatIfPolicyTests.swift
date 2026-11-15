import XCTest
@testable import ForgeCore

final class WhatIfPolicyTests: XCTestCase {
    func testSparksShowOnEveryCheck() {
        XCTAssertTrue(WhatIfPolicy.shows(confidence: 39, verdict: .cantTell))
        XCTAssertTrue(WhatIfPolicy.shows(confidence: 90, verdict: .buildIt), "a strong idea still has a sharper version")
        XCTAssertEqual(WhatIfPolicy.raisesLabel(criterionTitle: "Distribution"), "Raises Distribution")
    }
}
