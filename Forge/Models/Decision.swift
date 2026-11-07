import Foundation
import SwiftData

/// A dated entry in a project's decisions log. Also produced by a Ruling of "Agree".
@Model
public final class Decision {
    public var id: UUID = UUID()
    public var text: String = ""
    public var date: Date = Date()
    public var reason: String = ""
    public var project: Project?
    public var ruling: Ruling?

    public init(text: String, reason: String = "", date: Date = Date()) {
        self.text = text
        self.reason = reason
        self.date = date
    }
}
