import Foundation
import ForgeCore

enum VaultSort: String, CaseIterable, Identifiable {
    case recent, updated, potential, confidence

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .recent: "Recently captured"
        case .updated: "Recently updated"
        case .potential: "Potential"
        case .confidence: "Confidence"
        }
    }

    /// Potential and Confidence only compare within one lens (brief §4.5).
    var requiresLens: Bool { self == .potential || self == .confidence }
}

/// Pure search, filter and sort over ideas. No SwiftUI, so it is testable.
struct VaultFilter: Equatable {
    var searchText = ""
    var lens: LensType?
    var stage: Stage?
    var tag: String?
    var showArchived = false
    var sort: VaultSort = .recent

    var hasActiveFilter: Bool { lens != nil || stage != nil || tag != nil || showArchived }

    /// The sort actually applied: score sorts fall back to "updated" without a lens.
    var effectiveSort: VaultSort {
        (sort.requiresLens && lens == nil) ? .updated : sort
    }

    func apply(to ideas: [Idea]) -> [Idea] {
        var out = ideas.filter { $0.isArchived == showArchived }
        if let lens { out = out.filter { $0.lensType == lens } }
        if let stage { out = out.filter { $0.stage == stage } }
        if let tag {
            out = out.filter { idea in idea.tags.contains { $0.caseInsensitiveCompare(tag) == .orderedSame } }
        }
        let terms = searchText.lowercased().split(whereSeparator: \.isWhitespace).map(String.init)
        if !terms.isEmpty {
            out = out.filter { idea in
                let hay = idea.searchHaystack
                return terms.allSatisfy { hay.contains($0) }
            }
        }
        switch effectiveSort {
        case .recent:
            out.sort { $0.createdAt > $1.createdAt }
        case .updated:
            out.sort { $0.updatedAt > $1.updatedAt }
        case .potential:
            out.sort { ($0.latestEvaluation?.potential ?? -1, $0.updatedAt) > ($1.latestEvaluation?.potential ?? -1, $1.updatedAt) }
        case .confidence:
            out.sort { ($0.latestEvaluation?.confidence ?? -1, $0.updatedAt) > ($1.latestEvaluation?.confidence ?? -1, $1.updatedAt) }
        }
        return out
    }

    /// Every distinct tag across the given ideas, case-insensitively, sorted.
    static func allTags(in ideas: [Idea]) -> [String] {
        var seen: [String: String] = [:]
        for idea in ideas {
            for tag in idea.tags {
                let key = tag.lowercased()
                if seen[key] == nil { seen[key] = tag }
            }
        }
        return seen.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

extension Idea {
    /// Lowercased text the Vault search looks through.
    var searchHaystack: String {
        [title, originalText, notes, aiSummary ?? "", tags.joined(separator: " ")]
            .joined(separator: " ")
            .lowercased()
    }

    /// Parses "a, b, c" into clean tags.
    static func parseTags(_ text: String) -> [String] {
        var out: [String] = []
        for raw in text.split(whereSeparator: { $0 == "," || $0 == "\n" }) {
            let t = raw.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty, !out.contains(where: { $0.caseInsensitiveCompare(t) == .orderedSame }) {
                out.append(t)
            }
        }
        return out
    }
}
