import XCTest
@testable import ForgeCore

final class WhatIfPolicyTests: XCTestCase {
    func testPivotsShowWhenWeak() {
        XCTAssertTrue(WhatIfPolicy.shows(confidence: 39, verdict: .buildIt), "under 40 Confidence")
        XCTAssertTrue(WhatIfPolicy.shows(confidence: 80, verdict: .cantTell), "Go ask people")
        XCTAssertTrue(WhatIfPolicy.shows(confidence: 80, verdict: .compete), "Worth a fight")
        XCTAssertFalse(WhatIfPolicy.shows(confidence: 40, verdict: .buildIt))
        XCTAssertFalse(WhatIfPolicy.shows(confidence: 70, verdict: .useTheirs))
        XCTAssertEqual(WhatIfPolicy.raisesLabel(criterionTitle: "Distribution"), "Raises Distribution")
    }
}
