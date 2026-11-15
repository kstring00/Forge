import Foundation

/// Decision 0042: one check's shared research. The proxy builds it from the
/// research step: every finding names the page it came from. All five
/// panelists and the Brief read it; nothing after the check searches again.
public struct ResearchPacket: Codable, Equatable, Sendable {
    public enum Section: String, Codable, CaseIterable, Sendable {
        case competitors, prices, complaints, demand, other
    }

    public struct Finding: Codable, Equatable, Sendable {
        public var section: Section
        public var text: String
        /// The page it came from. Never empty: a line without a page is not a finding.
        public var url: String
        public var alsoURLs: [String]
        public var title: String

        public init(section: Section, text: String, url: String, alsoURLs: [String] = [], title: String) {
            self.section = section
            self.text = text
            self.url = url
            self.alsoURLs = alsoURLs
            self.title = title
        }
    }

    public var version: Int
    public var findings: [Finding]
    /// Lines the research wrote without a page. Kept, never shown as facts.
    public var unsourced: [String]
    /// What the research says it could not find.
    public var gaps: [String]

    public init(version: Int = 1, findings: [Finding], unsourced: [String] = [], gaps: [String] = []) {
        self.version = version
        self.findings = findings
        self.unsourced = unsourced
        self.gaps = gaps
    }

    /// Findings per section, in the packet's order.
    public func findings(in section: Section) -> [Finding] { findings.filter { $0.section == section } }

    /// Every page the packet cites, once.
    public var urls: [String] {
        var seen = Set<String>()
        return findings.flatMap { [$0.url] + $0.alsoURLs }.filter { seen.insert($0).inserted }
    }
}
