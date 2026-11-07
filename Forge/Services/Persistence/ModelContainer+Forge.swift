import Foundation
import SwiftData

public extension ModelContainer {
    /// The app's container. CloudKit is explicitly off; enabling it later is a
    /// one-line change here once the schema has been reviewed for sync.
    static func forge(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema(versionedSchema: ForgeSchemaV1.self)
        // In-memory containers get unique names so several can coexist in one
        // process (tests, previews) without sharing a store.
        let configuration = ModelConfiguration(
            inMemory ? "Forge-\(UUID().uuidString)" : "Forge",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: ForgeMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
