import Foundation
import SwiftData

/// Named `ProjectTask` to avoid colliding with Swift concurrency's `Task`.
@Model
public final class ProjectTask {
    public var id: UUID = UUID()
    public var title: String = ""
    public var done: Bool = false
    public var createdAt: Date = Date()
    public var completedAt: Date?
    public var milestone: Milestone?

    public init(title: String) {
        self.title = title
    }
}
