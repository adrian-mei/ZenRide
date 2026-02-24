import Foundation
import CoreLocation
import Combine
import SwiftUI

class NavigationEngine: ObservableObject {
    @Published var routeState: RouteState = .search
    @Published var isTracking: Bool = true
    
    // Core Services
    let locationProvider = LocationProvider()
    let cameraService = BunnyPolice()
    // Keeping routingService separate for now as it's heavily tied to the UI
    // but we can pass it in.
    
    // Drive context
    @Published var destinationName: String = ""
    private var departureTime: Date? = nil
    private var navigationStartTime: Date? = nil
    
    private var cancellables = Set<AnyCancellable>()
    
    // We inject RoutingService since it's already a heavy environment object used by many views.
    private weak var routingService: RoutingService?
    var onStopHook: ((RideContext?, PendingDriveSession?) -> Void)?
    
    init() {}
    
    func bind(routingService: RoutingService, cameras: [SpeedCamera]) {
        self.routingService = routingService
        self.cameraService.cameras = cameras
        
        locationProvider.$currentLocation
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loc in
                guard let self = self, self.routeState == .navigating else { return }
                self.routingService?.checkReroute(currentLocation: loc)
                self.cameraService.processLocation(loc, speedMPH: self.locationProvider.currentSpeedMPH)
            }
            .store(in: &cancellables)
            
        locationProvider.$simulationCompletedNaturally
            .removeDuplicates()
            .filter { $0 == true }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] completed in
                guard let self = self, self.routeState == .navigating else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                    if self.routeState == .navigating {
                        self.stopDrive()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    func startLiveDrive() {
        guard let routing = routingService, !routing.activeRoute.isEmpty else { return }
        departureTime = Date()
        navigationStartTime = Date()
        cameraService.startNavigationSession()
        locationProvider.startUpdatingLocation()
        routeState = .navigating
    }
    
    func startSimulatedDrive() {
        guard let routing = routingService, !routing.activeRoute.isEmpty else { return }
        departureTime = Date()
        navigationStartTime = Date()
        cameraService.startNavigationSession()
        locationProvider.simulateDrive(along: routing.activeRoute)
        routeState = .navigating
    }
    
    func cancelSearch() {
        routeState = .search
        destinationName = ""
        routingService?.availableRoutes = []
        routingService?.activeRoute = []
        routingService?.activeAlternativeRoutes = []
    }
    
    func stopDrive() {
        let context = buildRideContext()
        let pending = buildPendingSession(context: context)
        
        routeState = .search
        routingService?.activeRoute = []
        routingService?.availableRoutes = []
        routingService?.activeAlternativeRoutes = []
        
        cameraService.stopNavigationSession()
        locationProvider.stopUpdatingLocation()
        if locationProvider.isSimulating {
            locationProvider.stopSimulation()
        }
        
        onStopHook?(context, pending)
    }
    
    private func buildRideContext() -> RideContext? {
        guard !destinationName.isEmpty, let departure = departureTime else { return nil }
        guard let routing = routingService, let destCoord = routing.activeRoute.last,
              let originCoord = routing.activeRoute.first else { return nil }

        let address = destinationName
        let isSim = locationProvider.isSimulating

        let distanceMeters = locationProvider.isSimulating ? locationProvider.distanceTraveledInSimulationMeters : routing.distanceTraveledMeters
        let distanceMiles = distanceMeters * 0.000621371
        
        let context = RideContext(
            destinationName: address,
            destinationCoordinate: destCoord,
            originCoordinate: originCoord,
            routeDurationSeconds: Int(Date().timeIntervalSince(departure)),
            routeDistanceMeters: Int(distanceMeters),
            departureTime: departure
        )
        return context
    }
    
    private func buildPendingSession(context: RideContext?) -> PendingDriveSession? {
        guard let ctx = context else { return nil }
        
        return PendingDriveSession(
            speedReadings: cameraService.speedReadings,
            cameraZoneEvents: cameraService.cameraZoneEvents,
            topSpeedMph: cameraService.sessionTopSpeedMph,
            avgSpeedMph: cameraService.sessionAvgSpeedMph,
            zenScore: cameraService.zenScore,
            departureTime: ctx.departureTime,
            actualDurationSeconds: ctx.routeDurationSeconds,
            distanceMiles: Double(ctx.routeDistanceMeters) * 0.000621371,
            originCoord: ctx.originCoordinate,
            destCoord: ctx.destinationCoordinate,
            destinationName: ctx.destinationName,
            routeDurationSeconds: routingService?.routeTimeSeconds ?? 0
        )
    }
}
