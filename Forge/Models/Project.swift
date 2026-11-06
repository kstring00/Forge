import Foundation
import SwiftData
import ForgeCore

/// A chosen idea in the Workshop. Always has at most one `nextStep`.
@Model
public final class Project {
    public var id: UUID = UUID()
    public var name: String = ""
    public var projectDescription: String = ""
    public var desiredOutcome: String = ""
    public var statusRaw: String = ProjectStatus.active.rawValue
    public var notes: [String] = []
    public var resources: [String] = []
    public var nextStep: String?
    public var launchDefinition: String = ""
    public var retrospective: String?
    public var createdAt: Date = Date()
    public var pausedAt: Date?
    public var completedAt: Date?
    public var idea: Idea?
    @Relationship(deleteRule: .cascade, inverse: \Milestone.project) public var milestones: [Milestone] = []
    @Relationship(deleteRule: .cascade, inverse: \Decision.project) public var decisions: [Decision] = []

    public init(name: String, desiredOutcome: String = "") {
        self.name = name
        self.desiredOutcome = desiredOutcome
    }

    public var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .active }
        set { statusRaw = newValue.rawValue }
    }

    public var orderedMilestones: [Milestone] { milestones.sorted { $0.order < $1.order } }
}
