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
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}
