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
        
        // Mock a route
        let startCoord = CLLocationCoordinate2D(latitude: 37.005, longitude: -122.0)
        let endCoord = CLLocationCoordinate2D(latitude: 36.995, longitude: -122.0)
        routingService.activeRoute = [startCoord, endCoord]
        engine.destinationName = "Home"
        
        #expect(engine.routeState == .search)
        
        // Start simulation
        engine.startSimulatedDrive()
        
        #expect(engine.routeState == .navigating)
        #expect(engine.locationProvider.isSimulating == true)
        
        // Wait a small amount of time for the simulation to start and move
        try await Task.sleep(nanoseconds: 500_000_000)
        
        // Ensure location updates are feeding through
        #expect(engine.locationProvider.currentLocation != nil)
        
        // Stop the drive manually
        var capturedContext: RideContext?
        var capturedSession: PendingDriveSession?
        
        engine.onStopHook = { context, session in
            capturedContext = context
            capturedSession = session
        }
        
        engine.stopDrive()
        
        #expect(engine.routeState == .search)
        #expect(engine.locationProvider.isSimulating == false)
        #expect(capturedContext != nil)
        #expect(capturedSession != nil)
        #expect(capturedContext?.destinationName == "Home")
    }
}
