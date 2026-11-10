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

    /// Paying somebody else for the job is a workaround worth hearing about,
    /// not proof they would pay for this idea.
    func testMoneyPaidToSomeoneElseIsNotMoneyGiven() {
        XCTAssertEqual(RungInference.rungForConversation("Met the owner of Shady Oaks; she showed me her Facebook page and said she pays a nephew."), 3)
        XCTAssertEqual(RungInference.infer("He paid a nephew $200 last month and showed me the invoice.")?.rung, 3)
        XCTAssertEqual(RungInference.infer("They pay an agency in Austin.")?.rung, 3, "heard in a conversation, so time was given")
        XCTAssertEqual(RungInference.infer("She pays someone to update it.")?.rung, 3)
        XCTAssertEqual(RungInference.infer("He paid their old web guy for years.")?.rung, 3)

        // The payment itself, or money to me, still counts.
        XCTAssertEqual(RungInference.infer("Harbor View paid a $149 deposit for month one.")?.rung, 4)
        XCTAssertEqual(RungInference.infer("She paid a deposit on the spot.")?.rung, 4)
        XCTAssertEqual(RungInference.infer("He paid her first month up front.")?.rung, 4)
        XCTAssertEqual(RungInference.infer("She pays a nephew today. Then she paid me a $50 deposit.")?.rung, 4, "each sentence is read on its own")
        XCTAssertEqual(RungInference.infer("She pays a nephew but paid me $50 to try it.")?.rung, 4)
        XCTAssertEqual(RungInference.infer("He pays a nephew and came back to ask for a second quote.")?.rung, 5, "coming back is still coming back")
    }
}
