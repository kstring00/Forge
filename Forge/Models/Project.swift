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
    /// One muted line under the step: how to do it, or what not to do.
    public var nextStepCaveat: String?
    /// "1 of 5": conversations (or messages, or signups) logged against this step.
    public var nextStepTarget: Int = 1
    public var nextStepCount: Int = 0
    public var nextStepDueAt: Date?
    /// What reaching the target moves, in a few words ("moves Demand to rung 3").
    public var nextStepMoves: String?
    /// Decision 0030: the interview questions as the user edited them (nil until first opened).
    public var interviewQuestions: [String]?
    /// Decision 0030: drafts and finished interviews for this project's steps.
    public var interviews: [Interview] = []
    /// The criterion the step is testing; what the user brings back attaches here.
    public var nextStepCriterionKey: String?
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

    /// The stored target, or the count the step itself names when the stored
    /// value is still the default ("Talk to five parents" → 5). Older projects
    /// were written before the step's number was read.
    public var effectiveTarget: Int {
        if nextStepTarget > 1 { return nextStepTarget }
        if let step = nextStep, let n = NumberWords.firstNumber(in: step), (1...50).contains(n) { return n }
        return max(1, nextStepTarget)
    }
}
