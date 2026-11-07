import Foundation
import SwiftData
@testable import Forge

/// Holds an in-memory container for the life of a test. A `ModelContext` does
/// not retain its `ModelContainer`, so `ModelContainer(...).mainContext` as a
/// temporary leaves the context pointing at freed storage and the first insert
/// can trap. Keep the store in a property or a local that outlives every use.
@MainActor
final class TestStore {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer.forge(inMemory: true)
    }
}
