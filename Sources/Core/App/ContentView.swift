import SwiftUI
import MapKit
import CoreLocation
import Combine

struct ContentView: View {
    @State private var appState: AppState = {
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return .onboarding }
        return .garage
    }()

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
                RideView(onStop: { context, pending in
                    lastRideContext = context
                    pendingSession = pending

                    // Build toast info from ride stats
                    let distanceMiles = pending?.distanceMiles ?? 0
                    let zenScore = pending?.zenScore ?? 0
                    let moneySaved = Double((pending?.cameraZoneEvents ?? []).filter { $0.outcome == .saved }.count) * 100
                    postRideInfo = PostRideInfo(distanceMiles: distanceMiles, zenScore: zenScore, moneySaved: moneySaved)

                    // Save drive session immediately (no mood yet)
                    if let p = pending {
                        let session = p.toSession(mood: nil)
                        driveStore.appendSession(
                            originCoord: p.originCoord,
                            destCoord: p.destCoord,
                            destinationName: p.destinationName,
                            session: session
                        )
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

            // WindDown kept for backward compatibility but not used in primary flow
            case .windDown:
                WindDownView(
                    ticketsAvoided: bunnyPolice.camerasPassedThisRide,
                    zenScore: bunnyPolice.zenScore,
                    rideContext: lastRideContext,
                    cameraZoneEvents: pendingSession?.cameraZoneEvents ?? []
                ) { mood in
                    journal.addEntry(mood: mood, ticketsAvoided: bunnyPolice.camerasPassedThisRide, context: lastRideContext)

                    if let pending = pendingSession {
                        let session = pending.toSession(mood: mood)
                        driveStore.appendSession(
                            originCoord: pending.originCoord,
                            destCoord: pending.destCoord,
                            destinationName: pending.destinationName,
                            session: session
                        )
                    }

                    if let ctx = lastRideContext {
                        savedRoutes.recordVisit(
                            destinationName: ctx.destinationName,
                            coordinate: ctx.destinationCoordinate,
                            durationSeconds: ctx.routeDurationSeconds,
                            departureTime: ctx.departureTime
                        )
                    }

                    bunnyPolice.resetRideStats()
                    lastRideContext = nil
                    pendingSession = nil
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .garage }
                }
            }
        }
        // Sync vehicleMode whenever selected vehicle changes
        .onChange(of: vehicleStore.selectedVehicleMode) { mode in
            routingService.vehicleMode = mode
        }
    }
}
