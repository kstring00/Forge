import Foundation
import SwiftData

/// §6D. One current alternative found by a Reality Check, including
/// "do nothing" and DIY. Figures are quoted with the date fetched.
@Model
public final class Competitor {
    public var id: UUID = UUID()
    public var name: String = ""
    public var url: String?
    public var pricing: String = ""
    public var positioning: String = ""
    public var praises: [String] = []
    public var complaints: [String] = []
    public var tractionSignals: [String] = []
    public var fetchedAt: Date = Date()
    public var source: Source?
    public var realityCheck: RealityCheck?

    public init(name: String, url: String? = nil, pricing: String = "", positioning: String = "",
                praises: [String] = [], complaints: [String] = [], tractionSignals: [String] = [],
                fetchedAt: Date = Date(), source: Source? = nil) {
        self.name = name
        self.url = url
        self.pricing = pricing
        self.positioning = positioning
        self.praises = praises
        self.complaints = complaints
        self.tractionSignals = tractionSignals
        self.fetchedAt = fetchedAt
        self.source = source
    }
}
