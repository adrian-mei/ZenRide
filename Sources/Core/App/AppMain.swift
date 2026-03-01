import SwiftUI
import MapKit
import CoreLocation
import Combine
import SwiftData

@main
struct FashodaMapApp: App {
    @StateObject private var cameraStore = CameraStore()
    @StateObject private var parkingStore = ParkingStore()
    @StateObject private var bunnyPolice = BunnyPolice()
    @StateObject private var locationProvider = LocationProvider()
    @StateObject private var multiplayerService = MultiplayerService()
    @StateObject private var routingService = RoutingService()
    @StateObject private var journal = RideJournal()
    @StateObject private var savedRoutes = SavedRoutesStore()
    @StateObject private var driveStore = DriveStore()
    @StateObject private var vehicleStore = VehicleStore()
    @StateObject private var questStore = QuestStore()
    @StateObject private var playerStore = PlayerStore()
    @StateObject private var memoryStore = MemoryStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraStore)
                .environmentObject(parkingStore)
                .environmentObject(bunnyPolice)
                .environmentObject(locationProvider)
                .environmentObject(multiplayerService)
                .environmentObject(routingService)
                .environmentObject(journal)
                .environmentObject(savedRoutes)
                .environmentObject(driveStore)
                .environmentObject(vehicleStore)
                .environmentObject(questStore)
                .environmentObject(playerStore)
                .environmentObject(memoryStore)
                .onAppear {
                    bunnyPolice.cameras = cameraStore.cameras
                }
        }
        .modelContainer(SharedModelContainer.shared)
    }
}

enum AppState {
    case onboarding
    case garage
    case riding
}
