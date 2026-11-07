import Foundation
import SwiftData
import ForgeCore

/// §6C. One Sphere's single reply to one other Sphere. One exchange per pair.
@Model
public final class Crossfire {
    public var id: UUID = UUID()
    public var fromSphereRaw: String = Sphere.skeptic.rawValue
    public var toSphereRaw: String = Sphere.investor.rawValue
    public var text: String = ""
    public var round: Round?

    public init(from: Sphere, to: Sphere, text: String) {
        self.fromSphereRaw = from.rawValue
        self.toSphereRaw = to.rawValue
        self.text = text
    }

    public var fromSphere: Sphere { Sphere(rawValue: fromSphereRaw) ?? .skeptic }
    public var toSphere: Sphere { Sphere(rawValue: toSphereRaw) ?? .investor }
}
