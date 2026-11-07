import Foundation
import SwiftData
import ForgeCore

/// §6C. One Sphere's structured verdict. A verdict with no sources must be
/// `cantTell` and must say what evidence would change it.
@Model
public final class Verdict {
    public var id: UUID = UUID()
    public var sphereRaw: String = Sphere.skeptic.rawValue
    public var kindRaw: String = VerdictKind.cantTell.rawValue
    public var criterionKey: String = ""
    public var reason: String = ""
    public var evidenceNeeded: String?
    public var round: Round?
    public var sources: [Source] = []
    @Relationship(deleteRule: .cascade, inverse: \Ruling.verdict) public var ruling: Ruling?

    public init(sphere: Sphere, kind: VerdictKind, criterionKey: String, reason: String,
                sources: [Source] = [], evidenceNeeded: String? = nil) {
        self.sphereRaw = sphere.rawValue
        // Rule: no sources → cantTell, whatever the model said.
        self.kindRaw = (sources.isEmpty ? VerdictKind.cantTell : kind).rawValue
        self.criterionKey = criterionKey
        self.reason = reason
        self.sources = sources
        self.evidenceNeeded = evidenceNeeded
    }

    public var sphere: Sphere { Sphere(rawValue: sphereRaw) ?? .skeptic }
    public var kind: VerdictKind { VerdictKind(rawValue: kindRaw) ?? .cantTell }
}
