import XCTest
@testable import ForgeCore

final class RungInferenceTests: XCTestCase {
    func testTimeMoneyAndComingBack() {
        XCTAssertEqual(RungInference.infer("Talked to the owner of Shady Oaks for twenty minutes.")?.rung, 3)
        XCTAssertEqual(RungInference.infer("She paid the $149 deposit on the spot.")?.rung, 4)
        XCTAssertEqual(RungInference.infer("He renewed for month two and referred the park next door.")?.rung, 5)
        XCTAssertEqual(RungInference.infer("Sent the message, no reply yet."), nil, "a negated reply is not time given")
        XCTAssertNil(RungInference.infer("Thought about it on the drive home."))
    }

    func testTheHighestRungWinsAndNegationStepsDown() {
        XCTAssertEqual(RungInference.infer("We met for coffee and she paid for a pilot.")?.rung, 4)
        XCTAssertEqual(RungInference.infer("Great call, but they didn't pay and said maybe next year.")?.rung, 3)
    }

    func testAConversationIsNeverBelowThree() {
        XCTAssertEqual(RungInference.rungForConversation("Nice chat, nothing concrete."), 3)
        XCTAssertEqual(RungInference.rungForConversation("They bought two months up front."), 4)
        XCTAssertEqual(RungInference.label(4), "Gave money")
    }
}
