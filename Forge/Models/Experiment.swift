import Foundation
import SwiftData

/// Hypothesis · Test · Metric · Cost · Timebox · Decision rule.
@Model
public final class Experiment {
    public var id: UUID = UUID()
    public var hypothesis: String = ""
    public var test: String = ""
    public var metric: String = ""
    public var cost: String = ""
    public var timeboxDays: Int = 7
    public var decisionRule: String = ""
    public var outcome: String?
    public var createdAt: Date = Date()
    public var evaluation: Evaluation?
    public var ruling: Ruling?

    public init(hypothesis: String, test: String, metric: String, cost: String, timeboxDays: Int, decisionRule: String) {
        self.hypothesis = hypothesis
        self.test = test
        self.metric = metric
        self.cost = cost
        self.timeboxDays = timeboxDays
        self.decisionRule = decisionRule
    }
}
