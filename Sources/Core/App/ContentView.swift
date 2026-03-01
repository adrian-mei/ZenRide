import SwiftUI
import MapKit
import CoreLocation
import Combine

struct ContentView: View {
    @State private var appState: AppState = {
        guard UserDefaults.standard.bool(forKey: UserDefaultsKeys.hasCompletedOnboarding) else { return .onboarding }
        return .garage
    }()

    @State private var initialDestinationName: String = ""
    @State private var lastRideContext: RideContext? = nil
    @State private var pendingSession: PendingDriveSession? = nil
    @State private var postRideInfo: PostRideInfo? = nil
    @State private var pendingMoodSave: ((String) -> Void)? = nil

    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var journal: RideJournal
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var driveStore: DriveStore
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var playerStore: PlayerStore
    @EnvironmentObject var cameraStore: CameraStore

    var body: some View {
        Group {
            switch appState {

            case .onboarding:
                OnboardingView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .garage }
                }

            case .garage:
                MapHomeView(
                    onRollOut: {
                        initialDestinationName = ""
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .riding }
                    },
                    onDestinationSelected: { name, _ in
                        initialDestinationName = name
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .riding }
                    },
                    postRideInfo: postRideInfo,
                    pendingMoodSave: pendingMoodSave
                )
                .onAppear {
                    // Sync vehicle mode from store on every garage visit
                    routingService.vehicleMode = vehicleStore.selectedVehicleMode
                }

            case .riding:
                RideView(initialDestinationName: initialDestinationName, onStop: { context, pending in
                    initialDestinationName = ""
                    lastRideContext = context
                    pendingSession = pending

                    // Gamification: award XP via PlayerStore
                    let questWaypoints = routingService.completedQuestWaypointCount
                    routingService.completedQuestWaypointCount = 0
                    let xpEarned = playerStore.processRideEnd(
                        durationSeconds: pending?.actualDurationSeconds ?? 0,
                        avgSpeed: pending?.avgSpeedMph ?? 0,
                        distanceMiles: pending?.distanceMiles ?? 0,
                        questWaypointCount: questWaypoints
                    )

                    // Build toast info from ride stats
                    let distanceMiles = pending?.distanceMiles ?? 0
                    let zenScore = pending?.zenScore ?? 0
                    let moneySaved = Double((pending?.cameraZoneEvents ?? []).filter { $0.outcome == .saved }.count) * 100
                    postRideInfo = PostRideInfo(distanceMiles: distanceMiles, zenScore: zenScore, moneySaved: moneySaved, xpEarned: xpEarned)

                    // Save drive session immediately (no mood yet); check for new achievements after save
                    let prevAchievementCount = AchievementEngine.earnedCount(from: driveStore)
                    if let p = pending {
                        let session = p.toSession(mood: nil)
                        driveStore.appendSession(
                            originCoord: p.originCoord,
                            destCoord: p.destCoord,
                            destinationName: p.destinationName,
                            session: session
                        )
                    }
                    if let newAchievement = AchievementEngine.recentlyEarned(from: driveStore, previous: prevAchievementCount) {
                        playerStore.newlyEarnedAchievement = newAchievement
                    }

                    // Record route visit
                    if let ctx = context {
                        savedRoutes.recordVisit(
                            destinationName: ctx.destinationName,
                            coordinate: ctx.destinationCoordinate,
                            durationSeconds: ctx.routeDurationSeconds,
                            departureTime: ctx.departureTime
                        )
                    }

                    // Mood save closure — called from MoodSelectionCard or on dismiss
                    let capturedContext = context
                    let capturedCamerasAvoided = bunnyPolice.camerasPassedThisRide
                    pendingMoodSave = { mood in
                        if !mood.isEmpty {
                            journal.addEntry(
                                mood: mood,
                                ticketsAvoided: capturedCamerasAvoided,
                                context: capturedContext
                            )
                        }
                        bunnyPolice.resetRideStats()
                        lastRideContext = nil
                        pendingSession = nil
                        postRideInfo = nil
                        pendingMoodSave = nil
                    }

                    bunnyPolice.stopNavigationSession()

                    // Immediately back to garage (background save already done above)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { appState = .garage }
                })

            }
        }
        // Sync vehicleMode whenever selected vehicle changes
        .onChange(of: vehicleStore.selectedVehicleMode) { _, mode in
            routingService.vehicleMode = mode
        }
        .onChange(of: locationProvider.currentLocation) { _, loc in
            if let loc = loc {
                // If the user isn't in SF, give them some dynamic speed cameras to avoid!
                cameraStore.generateGlobalMockCameras(around: loc.coordinate)
                
                // Keep the radar system in sync with any newly generated cameras
                if bunnyPolice.cameras.count != cameraStore.cameras.count {
                    bunnyPolice.cameras = cameraStore.cameras
                }
            }
        }
    }
}
