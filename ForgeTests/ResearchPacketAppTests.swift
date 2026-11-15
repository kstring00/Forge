import XCTest
import SwiftData
import ForgeCore
@testable import Forge

/// Decision 0042: the packet is kept with the idea, and every later call on
/// the idea reads it instead of the pages.
@MainActor
final class ResearchPacketAppTests: XCTestCase {
    private var store: TestStore!

    override func setUp() async throws {
        store = try TestStore()
    }

    func testFollowUpsReadTheSavedPacketNotThePages() throws {
        let idea = Idea(originalText: "Website care for RV parks")
        store.context.insert(idea)
        let page = Source(kind: .web, title: "Campspot pricing", fullText: "Sites cost $35 to $65 a month", sourceClass: .aiFound, url: "https://www.campspot.com/pricing")
        page.chunks.append(SourceChunk(index: 0, text: "Sites cost $35 to $65 a month"))
        let talk = Source(kind: .note, title: "Conversation · Dale", fullText: "Dale said his site broke twice", sourceClass: .userVerified)
        talk.chunks.append(SourceChunk(index: 0, text: "Dale said his site broke twice"))
        idea.sources.append(contentsOf: [page, talk])

        // No packet yet (a check before this change): the pages go in full.
        XCTAssertEqual(AIContext.make(for: idea).sources.first { $0.id == page.id }?.chunks.count, 1)
        XCTAssertNil(AIContext.make(for: idea).packet)

        idea.researchPacket = ResearchPacket(findings: [
            .init(section: .prices, text: "Bundled sites cost $35 to $65 a month", url: "https://www.campspot.com/pricing", title: "Campspot pricing"),
            .init(section: .complaints, text: "Widgets break on mobile", url: "https://example.com/unsaved", title: "example.com"),
        ], gaps: ["Could not find search volume"])
        idea.researchedAt = Date(timeIntervalSince1970: 1_800_000_000)
        try store.context.save()

        let ctx = AIContext.make(for: idea)
        let packet = try XCTUnwrap(ctx.packet)
        XCTAssertEqual(packet.findings[0].sourceID, page.id, "a finding cites the source with its page's address")
        XCTAssertNil(packet.findings[1].sourceID, "no saved page, no id: the panel can't cite it")
        XCTAssertEqual(packet.gaps, ["Could not find search volume"])
        XCTAssertNotNil(packet.researchedAt)
        XCTAssertEqual(ctx.sources.first { $0.id == page.id }?.chunks.count, 0, "pages go by title; the packet carries what they showed")
        XCTAssertEqual(ctx.sources.first { $0.id == talk.id }?.chunks.count, 1, "the person's own evidence goes in full")
    }
}
