import Foundation
import SwiftData
import ForgeCore

/// User-maintained. The AI never infers these.
@Model
public final class Advantage {
    public var id: UUID = UUID()
    public var text: String = ""
    public var kindRaw: String = AdvantageKind.skill.rawValue
    public var createdAt: Date = Date()

    public init(text: String, kind: AdvantageKind) {
        self.text = text
        self.kindRaw = kind.rawValue
    }

    public var kind: AdvantageKind { AdvantageKind(rawValue: kindRaw) ?? .skill }
}
