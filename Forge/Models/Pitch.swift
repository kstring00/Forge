import Foundation
import SwiftData
import ForgeCore

@Model
public final class Pitch {
    public var id: UUID = UUID()
    public var title: String = ""
    public var body: String = ""
    public var forWhom: String = ""
    public var whyNow: String = ""
    public var advantageUsed: String = ""
    public var riskiestAssumption: String = ""
    public var clusterRaw: String = PitchCluster.asset.rawValue
    public var sphereRaw: String?
    public var createdAt: Date = Date()
    public var statusRaw: String = PitchStatus.open.rawValue
    public var rejectionReason: String?
    public var savedIdea: Idea?

    public init(title: String, body: String, forWhom: String, whyNow: String,
                advantageUsed: String, riskiestAssumption: String, cluster: PitchCluster, sphere: Sphere? = nil) {
        self.title = title
        self.body = body
        self.forWhom = forWhom
        self.whyNow = whyNow
        self.advantageUsed = advantageUsed
        self.riskiestAssumption = riskiestAssumption
        self.clusterRaw = cluster.rawValue
        self.sphereRaw = sphere?.rawValue
    }

    public var cluster: PitchCluster { PitchCluster(rawValue: clusterRaw) ?? .asset }
    public var sphere: Sphere? { sphereRaw.flatMap(Sphere.init(rawValue:)) }

    public var status: PitchStatus {
        get { PitchStatus(rawValue: statusRaw) ?? .open }
        set { statusRaw = newValue.rawValue }
    }
}
