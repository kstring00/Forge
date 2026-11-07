import Foundation
import SwiftData

/// Versioned schema so CloudKit sync and migrations can be added without
/// touching the models. V1 is the Phase 0 schema: every model the brief names.
public enum ForgeSchemaV1: VersionedSchema {
    public static let versionIdentifier = Schema.Version(1, 0, 0)

    public static var models: [any PersistentModel.Type] {
        [
            Idea.self, OpportunityFilter.self, Exploration.self,
            Evaluation.self, CriterionScore.self, Evidence.self, Experiment.self,
            Source.self, SourceChunk.self, LibraryArtifact.self,
            Project.self, Milestone.self, ProjectTask.self, Decision.self,
            Pitch.self, Advantage.self, Constraint.self,
            Round.self, Verdict.self, Crossfire.self, Ruling.self, StewardCharter.self
        ]
    }
}

public enum ForgeMigrationPlan: SchemaMigrationPlan {
    public static var schemas: [any VersionedSchema.Type] { [ForgeSchemaV1.self] }
    public static var stages: [MigrationStage] { [] }
}
