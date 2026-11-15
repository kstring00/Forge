import XCTest
@testable import ForgeCore

/// Decision 0042: the packet decodes exactly as the proxy writes it.
final class ResearchPacketTests: XCTestCase {
    func testThePacketDecodesFromTheProxy() throws {
        let json = """
        {"version":1,"findings":[
          {"section":"prices","text":"Bundled sites cost $35 to $65 a month","url":"https://www.campspot.com/pricing","alsoURLs":[],"title":"Campspot pricing"},
          {"section":"competitors","text":"RoverPass offers sites to its own parks","url":"https://roverpass.com/websites","alsoURLs":["https://www.g2.com/products/roverpass/reviews"],"title":"roverpass.com"}],
         "unsourced":["Parks hate long contracts"],"gaps":["Could not find search volume"]}
        """
        let p = try JSONDecoder().decode(ResearchPacket.self, from: Data(json.utf8))
        XCTAssertEqual(p.findings(in: .prices).count, 1)
        XCTAssertEqual(p.urls, ["https://www.campspot.com/pricing", "https://roverpass.com/websites", "https://www.g2.com/products/roverpass/reviews"])
        XCTAssertEqual(p.unsourced, ["Parks hate long contracts"])
        XCTAssertEqual(try JSONDecoder().decode(ResearchPacket.self, from: JSONEncoder().encode(p)), p)
    }
}
