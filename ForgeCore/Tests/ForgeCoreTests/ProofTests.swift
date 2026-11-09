import XCTest
@testable import ForgeCore

/// Decision 0037.
final class ProofTests: XCTestCase {
    func testSourcesAreRankedByWhereTheyCameFrom() {
        XCTAssertEqual(EvidenceRank.classify(url: "https://www.reddit.com/r/Parenting/comments/x"), .discussed)
        XCTAssertEqual(EvidenceRank.classify(url: "https://www.g2.com/products/x/reviews"), .reviewed)
        XCTAssertEqual(EvidenceRank.classify(url: "https://acme.com/pricing"), .published)
        XCTAssertEqual(EvidenceRank.classify(url: "https://forum.acme.com/t/1"), .discussed)
        XCTAssertEqual(EvidenceRank.classify(url: nil, modelWritten: true), .opinion)
    }

    /// The test asked for: different source quality, different desk scores.
    func testTwoIdeasWithDifferentSourceQualityGetDifferentDeskScores() {
        let oneForumPost = DeskGrade.level(sources: [(url: "https://reddit.com/r/a/1", rank: .discussed)], proposedLevel: 2)
        let threeReviewed = DeskGrade.level(sources: [
            (url: "https://g2.com/a/reviews", rank: .reviewed),
            (url: "https://capterra.com/a/reviews", rank: .reviewed),
            (url: "https://trustpilot.com/review/a", rank: .reviewed),
        ], proposedLevel: 2)
        XCTAssertEqual(oneForumPost.level, 1.2)
        XCTAssertEqual(threeReviewed.level, 2.0)
        XCTAssertEqual(threeReviewed.independentSources, 3)
        XCTAssertNotEqual(oneForumPost.level, threeReviewed.level)

        let sameSiteTwice = DeskGrade.level(sources: [
            (url: "https://reddit.com/r/a/1", rank: .discussed), (url: "https://www.reddit.com/r/a/2", rank: .discussed),
        ], proposedLevel: 2)
        XCTAssertEqual(sameSiteTwice.level, 1.2, "one site counts once")
        let onlyOpinion = DeskGrade.level(sources: [(url: nil, rank: .opinion)], proposedLevel: 2)
        XCTAssertEqual(onlyOpinion.level, 1.0, "the model's own notes never count; no source means at most 1")
        XCTAssertEqual(onlyOpinion.independentSources, 0)

        // Six criteria: graded desk levels no longer collapse onto the same Confidence.
        let a = Scoring.confidence(levels: [1.2, 1, 1, 1, 1, 1])
        let b = Scoring.confidence(levels: [2.0, 1.4, 1, 1, 1, 1])
        XCTAssertNotEqual(a, b)
        XCTAssertEqual(Scoring.confidence(levels: [3, 1, 1, 1, 1, 1]), 27, "a conversation at level 3 outranks any desk score")
    }

    func testReturnIsBottomUpAndNeverWiderThanTenTimes() {
        typealias I = ReturnInputs.Input
        let sourced = UUID()
        let fine = ReturnInputs(price: I(low: 20, high: 30, basis: "clinic pricing page", sourceID: sourced),
                                reachable: I(low: 20, high: 40, basis: "clinics within 50 miles", sourceID: sourced),
                                conversion: I(low: 0.1, high: 0.2, basis: "assumed"))
        guard case .range(let lo, let hi, let narrowed) = fine.outcome else { return XCTFail() }
        XCTAssertEqual(lo, 40, accuracy: 0.01)
        XCTAssertEqual(hi, 240, accuracy: 0.01)
        XCTAssertFalse(narrowed)

        let wide = ReturnInputs(price: I(low: 5, high: 50, basis: "p", sourceID: sourced),
                                reachable: I(low: 10, high: 1000, basis: "r"), conversion: I(low: 0.05, high: 0.5, basis: "c"))
        guard case .range(let wl, let wh, let wn) = wide.outcome else { return XCTFail() }
        XCTAssertTrue(wn)
        XCTAssertEqual(wh / wl, 10, accuracy: 0.001)

        let noPrice = ReturnInputs(price: I(low: 19, high: 49, basis: "a competitor's report price"),
                                   reachable: I(low: 10, high: 20, basis: "r", sourceID: sourced), conversion: I(low: 0.1, high: 0.2, basis: "c"))
        XCTAssertEqual(noPrice.outcome, .tooEarly(ReturnInputs.noPrice), "a price must rest on a source for this idea")
    }

    func testMovesReadPlainly() {
        let m = ProofMove(at: Date(timeIntervalSince1970: 0), delta: 7, from: "Dale", criterionTitle: "Demand", levelAfter: 3)
        XCTAssertEqual(m.line, "+7 from Dale")
        XCTAssertTrue(m.isRecent(now: Date(timeIntervalSince1970: 3600)))
        XCTAssertFalse(m.isRecent(now: Date(timeIntervalSince1970: 90_000)))
    }
}
