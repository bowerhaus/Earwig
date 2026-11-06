import Foundation
import os
import SwiftData

/// The SwiftData schema and containers (PRD §6.1).
enum ModelContainerFactory {
    static let schema = Schema([Script.self, Step.self, Take.self, Rendering.self])

    private static let logger = Logger(subsystem: "com.bowerhaus.Earwig", category: "ModelContainer")

    /// The app's store. Falls back to memory, logged, if the store cannot be opened, so the app
    /// still starts.
    static func persistent() -> ModelContainer {
        do {
            return try ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema))
        } catch {
            logger.fault("Could not open the store, running from memory: \(error.localizedDescription)")
            return inMemory()
        }
    }

    /// For tests and previews.
    static func inMemory() -> ModelContainer {
        // The schema is fixed, so an in-memory container cannot fail to open.
        try! ModelContainer(for: schema, configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true))
    }
}
