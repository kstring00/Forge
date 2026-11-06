import Foundation
import SwiftData

@Model
public final class Milestone {
    public var id: UUID = UUID()
    public var title: String = ""
    public var order: Int = 0
    public var done: Bool = false
    public var project: Project?
    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.milestone) public var tasks: [ProjectTask] = []

    public init(title: String, order: Int) {
        self.title = title
        self.order = order
    }
}
