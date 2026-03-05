import Foundation
import CoreLocation
import SwiftUI
import Combine

@MainActor
class RideViewModel: ObservableObject {
    @Published var routeState: RouteState
    @Published var destinationName: String
    @Published var uiVisible = true
    @Published var showTapHint = false
    @Published var departureTime: Date?
    @Published var navigationStartTime: Date?
    @Published var isTracking: Bool = true
    @Published var mapMode: MapMode = .turnByTurn
    @Published var cruiseOdometerMiles: Double = 0
    @Published var cruiseLastLocation: CLLocation?
    @Published var showCruiseSearch = false
    @Published var celebrationStopName: String?
    @Published var flashTriggered = false
    
    // Dependencies
    private var routingService: RoutingService?
    private var bunnyPolice: BunnyPolice?
    private var locationProvider: LocationProvider?
    private var multiplayerService: MultiplayerService?
    
    var onStop: ((RideContext?, PendingDriveSession?) -> Void)?
    
    init(initialDestinationName: String) {
        self.destinationName = initialDestinationName
        self.routeState = initialDestinationName.isEmpty ? .navigating : .reviewing
    }
    
    func setup(
        routingService: RoutingService,
        bunnyPolice: BunnyPolice,
        locationProvider: LocationProvider,
        multiplayerService: MultiplayerService,
        onStop: @escaping (RideContext?, PendingDriveSession?) -> Void
    ) {
        self.routingService = routingService
        self.bunnyPolice = bunnyPolice
        self.locationProvider = locationProvider
        self.multiplayerService = multiplayerService
        self.onStop = onStop
    }
    
    func handleOnAppear() {
        if destinationName.isEmpty {
            departureTime = Date()
            navigationStartTime = Date()
            bunnyPolice?.startNavigationSession()
            locationProvider?.isSimulating = false
            showTapHint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation { self.showTapHint = false }
            }
        }
    }
    
    func handleLocationChange(_ location: CLLocation?) {
        guard routeState == .navigating, let loc = location,
              let routingService = routingService,
              let bunnyPolice = bunnyPolice,
              let locationProvider = locationProvider,
              let multiplayerService = multiplayerService else { return }
              
        routingService.checkReroute(currentLocation: loc)
        bunnyPolice.processLocation(loc, speedMPH: locationProvider.currentSpeedMPH)
        multiplayerService.broadcastLocalLocation(
            coordinate: loc.coordinate,
            heading: loc.course >= 0 ? loc.course : 0,
            speedMph: locationProvider.currentSpeedMPH,
            route: routingService.activeRoute,
            etaSeconds: routingService.routeTimeSeconds
        )
        if routingService.activeRoute.isEmpty {
            if let last = cruiseLastLocation {
                let deltaMeters = loc.distance(from: last)
                if deltaMeters < 800 {
                    cruiseOdometerMiles += deltaMeters / Constants.metersPerMile
                }
            }
            cruiseLastLocation = loc
        }
    }

    func handleSimulationCompletion(_ completed: Bool) {
        guard completed && routeState == .navigating,
              let routingService = routingService,
              let locationProvider = locationProvider else { return }

        if let quest = routingService.questManager.activeQuest {
            let reachedStopName = quest.waypoints[routingService.questManager.currentStopNumber].name
            celebrationStopName = reachedStopName

            if let loc = locationProvider.currentLocation?.coordinate {
                if let (start, end) = routingService.questManager.advanceToNextLeg(currentLocation: loc) {
                    Task {
                        do {
                            let result = try await QuestNavigationManager.generateLegRouting(from: start, to: end)
                            routingService.loadLeg(result: result)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                                if !routingService.activeRoute.isEmpty && self.celebrationStopName == nil {
                                    locationProvider.simulateDrive(along: routingService.activeRoute, speedMPH: routingService.vehicleMode.simulationSpeedMPH)
                                }
                            }
                        } catch {
                            Log.error("RideViewModel", "Failed to generate next leg: \(error)")
                        }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        self.endRide()
                    }
                }
            }
        } else {
            celebrationStopName = destinationName
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                if self.routeState == .navigating {
                    self.endRide()
                }
            }
        }
    }
    func buildRideContext() -> RideContext? {
        guard !destinationName.isEmpty, let departure = departureTime, let routingService = routingService else { return nil }
        guard let destCoord = routingService.activeRoute.last,
              let originCoord = routingService.activeRoute.first else { return nil }
        return RideContext(
            destinationName: destinationName,
            destinationCoordinate: destCoord,
            originCoordinate: originCoord,
            routeDurationSeconds: routingService.routeTimeSeconds,
            routeDistanceMeters: routingService.routeDistanceMeters,
            departureTime: departure
        )
    }

    func buildPendingSession(context: RideContext?) -> PendingDriveSession? {
        guard let ctx = context, let startTime = navigationStartTime, let bunnyPolice = bunnyPolice else { return nil }
        let actualDuration = Int(Date().timeIntervalSince(startTime))
        let distanceMiles = Double(ctx.routeDistanceMeters) / Constants.metersPerMile
        return PendingDriveSession(
            speedReadings: bunnyPolice.speedReadings,
            cameraZoneEvents: bunnyPolice.cameraZoneEvents,
            topSpeedMph: bunnyPolice.sessionTopSpeedMph,
            avgSpeedMph: bunnyPolice.sessionAvgSpeedMph,
            zenScore: bunnyPolice.zenScore,
            departureTime: ctx.departureTime,
            actualDurationSeconds: max(actualDuration, ctx.routeDurationSeconds),
            distanceMiles: distanceMiles,
            originCoord: ctx.originCoordinate,
            destCoord: ctx.destinationCoordinate,
            destinationName: ctx.destinationName,
            routeDurationSeconds: ctx.routeDurationSeconds
        )
    }

    func endRide() {
        let context = buildRideContext()
        let pending = buildPendingSession(context: context)
        bunnyPolice?.stopNavigationSession()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            routingService?.activeRoute = []
            routingService?.availableRoutes = []
            routingService?.activeAlternativeRoutes = []
            locationProvider?.stopSimulation()
            onStop?(context, pending)
        }
    }
    
    func reportHazard() {
        guard let location = locationProvider?.currentLocation else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("DropHazardPin"),
            object: location.coordinate
        )
        // Note: UIImpactFeedbackGenerator should be moved to View level
    }
}
