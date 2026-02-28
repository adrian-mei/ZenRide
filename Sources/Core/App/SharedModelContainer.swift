import Foundation
import SwiftData

@MainActor
class SharedModelContainer {
    static let shared: ModelContainer = {
        let schema = Schema([
            DriveRecord.self,
            DriveSession.self,
            CameraZoneEvent.self,
            SavedRoute.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            let container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            return container
        } catch {
            Log.error("SharedModelContainer", "Persistent store failed, falling back to in-memory: \(error)")
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                return try ModelContainer(for: schema, configurations: [fallbackConfig])
            } catch {
                fatalError("Could not create in-memory ModelContainer: \(error)")
            }
        }
    }()
}
