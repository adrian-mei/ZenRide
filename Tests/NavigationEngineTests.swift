import Testing
import Foundation
import CoreLocation
@testable import ZenRide

@MainActor
struct NavigationEngineTests {

    @Test func testNavigationEngineSimulatedRideLifecycle() async throws {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        
        let camera = SpeedCamera(
            id: "cam-1",
            street: "Main St",
            from_cross_street: nil,
            to_cross_street: nil,
            speed_limit_mph: 30,
            lat: 37.0,
            lng: -122.0
        )
        
        engine.bind(routingService: routingService, cameras: [camera])
        
        let startCoord = CLLocationCoordinate2D(latitude: 37.005, longitude: -122.0)
        let endCoord = CLLocationCoordinate2D(latitude: 36.995, longitude: -122.0)
        routingService.activeRoute = [startCoord, endCoord]
        engine.destinationName = "Home"
        
        #expect(engine.routeState == .search)
        
        engine.startSimulatedDrive()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(engine.routeState == .navigating)
        #expect(engine.locationProvider.isSimulating == true)
        
        try await Task.sleep(nanoseconds: 500_000_000)
        
        #expect(engine.locationProvider.currentLocation != nil)
        
        var capturedContext: RideContext?
        var capturedSession: PendingDriveSession?
        
        engine.onStopHook = { context, session in
            capturedContext = context
            capturedSession = session
        }
        
        engine.stopDrive()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(engine.routeState == .search)
        #expect(engine.locationProvider.isSimulating == false)
        #expect(capturedContext != nil)
        #expect(capturedSession != nil)
        #expect(capturedContext?.destinationName == "Home")
    }

    @Test func emptyStartsIgnored() {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        
        engine.bind(routingService: routingService, cameras: [])
        
        routingService.activeRoute = []
        
        #expect(engine.routeState == .search)
        
        engine.startLiveDrive()
        #expect(engine.routeState == .search)
        
        engine.startSimulatedDrive()
        #expect(engine.routeState == .search)
    }

    @Test func cancelSearchResetsState() {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        
        engine.bind(routingService: routingService, cameras: [])
        
        engine.routeState = .search
        engine.destinationName = "Home"
        
        routingService.availableRoutes = [TomTomRoute(summary: TomTomSummary(lengthInMeters: 10, travelTimeInSeconds: 10), tags: nil, legs: [], guidance: nil)]
        routingService.activeRoute = [CLLocationCoordinate2D(latitude: 0, longitude: 0)]
        routingService.activeAlternativeRoutes = [[CLLocationCoordinate2D(latitude: 0, longitude: 0)]]
        
        engine.cancelSearch()
        
        #expect(engine.routeState == .search)
        #expect(engine.destinationName == "")
        #expect(routingService.availableRoutes.isEmpty)
        #expect(routingService.activeRoute.isEmpty)
        #expect(routingService.activeAlternativeRoutes.isEmpty)
    }

    @Test func stopDriveContextualIntegritySimulated() async throws {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        
        engine.bind(routingService: routingService, cameras: [])
        
        let startCoord = CLLocationCoordinate2D(latitude: 37.000, longitude: -122.0)
        let endCoord = CLLocationCoordinate2D(latitude: 37.010, longitude: -122.0)
        routingService.activeRoute = [startCoord, endCoord]
        engine.destinationName = "Home"
        
        engine.startSimulatedDrive()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Manually set simulation distance
        engine.locationProvider.distanceTraveledInSimulationMeters = 150.0
        
        var capturedContext: RideContext?
        engine.onStopHook = { context, session in
            capturedContext = context
        }
        
        engine.stopDrive()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(capturedContext?.routeDistanceMeters == 150)
    }

    @Test func stopDriveContextualIntegrityLive() async throws {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        
        engine.bind(routingService: routingService, cameras: [])
        
        let data = MockRoutingData.tomTomResponseJSON.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(TomTomRouteResponse.self, from: data)
        routingService.availableRoutes = decoded.routes
        routingService.selectRoute(at: 0)
        
        engine.destinationName = "Work"
        
        engine.startLiveDrive()
        
        routingService.routeProgressIndex = 1
        let expectedDistance = routingService.distanceTraveledMeters
        
        var capturedContext: RideContext?
        engine.onStopHook = { context, session in
            capturedContext = context
        }
        
        engine.stopDrive()
        
        #expect(capturedContext?.routeDistanceMeters == Int(expectedDistance))
    }

    @Test func stopDriveWithoutStarting() {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        engine.bind(routingService: routingService, cameras: [])
        
        var capturedContext: RideContext?
        var capturedSession: PendingDriveSession?
        var hookCalled = false
        
        engine.onStopHook = { context, session in
            capturedContext = context
            capturedSession = session
            hookCalled = true
        }
        
        engine.stopDrive()
        
        #expect(hookCalled == true)
        #expect(capturedContext == nil)
        #expect(capturedSession == nil)
    }

    @Test func stopDriveWithEmptyDestinationName() {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        engine.bind(routingService: routingService, cameras: [])
        
        let startCoord = CLLocationCoordinate2D(latitude: 37.000, longitude: -122.0)
        let endCoord = CLLocationCoordinate2D(latitude: 37.010, longitude: -122.0)
        routingService.activeRoute = [startCoord, endCoord]
        
        engine.destinationName = ""
        engine.startSimulatedDrive()
        
        var capturedContext: RideContext?
        var capturedSession: PendingDriveSession?
        
        engine.onStopHook = { context, session in
            capturedContext = context
            capturedSession = session
        }
        
        engine.stopDrive()
        
        #expect(capturedContext == nil)
        #expect(capturedSession == nil)
    }

    @Test func locationUpdatesIgnoredWhenNotNavigating() async throws {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        let camera = SpeedCamera(id: "cam-1", street: "St", from_cross_street: nil, to_cross_street: nil, speed_limit_mph: 30, lat: 37.0, lng: -122.0)
        engine.bind(routingService: routingService, cameras: [camera])
        
        let startCoord = CLLocationCoordinate2D(latitude: 37.000, longitude: -122.0)
        let endCoord = CLLocationCoordinate2D(latitude: 37.010, longitude: -122.0)
        routingService.activeRoute = [startCoord, endCoord]
        engine.destinationName = "Home"
        
        #expect(engine.routeState == .search)
        
        let loc = CLLocation(latitude: 37.0, longitude: -122.0)
        engine.locationProvider.currentLocation = loc
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(engine.cameraService.camerasPassedThisRide == 0)
        #expect(engine.cameraService.currentZone == .safe)
    }

    @Test func navigationIntegrationE2E() async throws {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        routingService.useMockData = true
        
        let startCoord = CLLocationCoordinate2D(latitude: 37.77490, longitude: -122.41940)
        let endCoord = CLLocationCoordinate2D(latitude: 37.78300, longitude: -122.40300)
        
        let camera = SpeedCamera(
            id: "cam-e2e",
            street: "Route St",
            from_cross_street: nil,
            to_cross_street: nil,
            speed_limit_mph: 30,
            lat: 37.77850,
            lng: -122.41200
        )
        
        engine.bind(routingService: routingService, cameras: [camera])
        
        await routingService.calculateSafeRoute(from: startCoord, to: endCoord, avoiding: [camera])
        
        #expect(!routingService.availableRoutes.isEmpty)
        #expect(!routingService.activeRoute.isEmpty)
        
        engine.destinationName = "End of Route"
        
        var capturedContext: RideContext?
        var capturedSession: PendingDriveSession?
        
        engine.onStopHook = { context, session in
            capturedContext = context
            capturedSession = session
        }
        
        engine.startSimulatedDrive()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(engine.routeState == .navigating)
        #expect(engine.locationProvider.isSimulating == true)
        
        // Inject mock readings to simulate the BunnyPolice timer having run during the drive
        engine.cameraService.speedReadings = [65.0, 70.0]
        
        engine.stopDrive()
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(capturedSession?.speedReadings == [65.0, 70.0])
        
        engine.routeState = .search
        
        // Hijack with tiny route
        let p1 = CLLocationCoordinate2D(latitude: 37.77490, longitude: -122.41940)
        let p2 = CLLocationCoordinate2D(latitude: 37.77500, longitude: -122.41940)
        routingService.activeRoute = [p1, p2]
        
        var stopHookCalled = false
        engine.onStopHook = { context, session in
            capturedContext = context
            capturedSession = session
            stopHookCalled = true
        }
        
        engine.startSimulatedDrive()
        
        // Wait for tiny drive to finish + 4s engine delay
        try await Task.sleep(nanoseconds: 5_000_000_000)
        
        #expect(engine.locationProvider.simulationCompletedNaturally == true)
        #expect(engine.routeState == .search)
        #expect(stopHookCalled == true)
        
        #expect(capturedContext != nil)
        #expect(capturedSession != nil)
        #expect(capturedContext?.destinationName == "End of Route")
    }

    @Test func simulationCompletedNaturallyButCancelledBeforeDelay() async throws {
        let engine = NavigationEngine()
        let routingService = RoutingService()
        engine.bind(routingService: routingService, cameras: [])
        
        let startCoord = CLLocationCoordinate2D(latitude: 37.000, longitude: -122.0)
        let endCoord = CLLocationCoordinate2D(latitude: 37.010, longitude: -122.0)
        routingService.activeRoute = [startCoord, endCoord]
        engine.destinationName = "Home"
        
        engine.startSimulatedDrive()
        
        // Let it get into navigating state
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(engine.routeState == .navigating)
        
        var hookCallCount = 0
        engine.onStopHook = { context, session in
            hookCallCount += 1
        }
        
        // Trigger completion manually
        engine.locationProvider.simulationCompletedNaturally = true
        
        // Wait 1 second (less than the 4 second delay)
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Cancel the drive manually
        engine.stopDrive()
        
        // Wait 4 more seconds to ensure the asyncAfter block executes
        try await Task.sleep(nanoseconds: 4_000_000_000)
        
        // stopDrive should only have been called ONCE (manually), because the async block
        // checks `if self.routeState == .navigating` which is now false.
        #expect(hookCallCount == 1)
        #expect(engine.routeState == .search)
    }
}
