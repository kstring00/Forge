import Foundation
import SwiftData

/// A claim tied to a criterion, pointing at a Source. Raises Confidence only
/// if the source is user-verified or a reviewed AI find.
@Model
public final class Evidence {
    public var id: UUID = UUID()
    public var criterionKey: String = ""
    public var ladderRung: Int = 0
    public var text: String = ""
    public var createdAt: Date = Date()
    public var source: Source?
    public var criterionScore: CriterionScore?

    public init(criterionKey: String, ladderRung: Int, text: String, source: Source? = nil) {
        self.criterionKey = criterionKey
        self.ladderRung = min(max(ladderRung, 0), 5)
        self.text = text
        self.source = source
    }

    /// Whether this evidence may count toward Confidence.
    public var countsTowardConfidence: Bool {
        guard let source else { return false }
        switch source.sourceClass {
        case .userVerified: return true
        case .aiFound: return source.reviewed
        case .assumption: return false
        }
    }
}
