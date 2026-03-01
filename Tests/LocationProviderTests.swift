import Testing
import Foundation
import CoreLocation
@testable import FashodaMap

@MainActor
struct LocationProviderTests {

    @Test func simulationLifecycle() async throws {
        let provider = LocationProvider()
        
        provider.startSimulation(
            origin: CLLocationCoordinate2D(latitude: 37.000, longitude: -122.000),
            destination: CLLocationCoordinate2D(latitude: 37.010, longitude: -122.010)
        )
        
        #expect(provider.isSimulating == true)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(provider.currentLocation != nil)
        #expect(provider.currentSpeedMPH == 45.0)
        
        provider.stopSimulation()
        
        #expect(provider.isSimulating == false)
    }
    
    @Test func invalidRoutesForSimulation() async throws {
        let provider = LocationProvider()
        
        provider.startSimulationWithRoute([])
        #expect(provider.isSimulating == false)
        
        provider.startSimulationWithRoute([CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)])
        #expect(provider.isSimulating == false)
    }

    @Test func simulationUsingRealRoute() async throws {
        let provider = LocationProvider()
        
        let p1 = CLLocationCoordinate2D(latitude: 37.000, longitude: -122.000)
        let p2 = CLLocationCoordinate2D(latitude: 37.005, longitude: -122.000)
        let p3 = CLLocationCoordinate2D(latitude: 37.010, longitude: -122.000)
        
        provider.startSimulationWithRoute([p1, p2, p3])
        
        #expect(provider.isSimulating == true)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(provider.currentLocation != nil)
        
        provider.stopSimulation()
        #expect(provider.isSimulating == false)
    }

    @Test func ignoredLiveUpdatesWhenSimulating() async throws {
        let provider = LocationProvider()
        provider.startSimulation(
            origin: CLLocationCoordinate2D(latitude: 37.000, longitude: -122.000),
            destination: CLLocationCoordinate2D(latitude: 37.010, longitude: -122.010)
        )
        
        try await Task.sleep(nanoseconds: 100_000_000)
        let simLoc = provider.currentLocation
        
        let fakeLiveLoc = CLLocation(latitude: 0, longitude: 0)
        provider.locationManager(CLLocationManager(), didUpdateLocations: [fakeLiveLoc])
        
        #expect(provider.currentLocation?.coordinate.latitude != 0)
        #expect(provider.currentLocation?.coordinate.latitude == simLoc?.coordinate.latitude)
        
        provider.stopSimulation()
    }

    @Test func speedConversion() async throws {
        let provider = LocationProvider()
        provider.isSimulating = false
        
        // 10 m/s = 22.3694 mph
        let loc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 10), altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 10, timestamp: Date())
        
        provider.locationManager(CLLocationManager(), didUpdateLocations: [loc])
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(provider.currentLocation != nil)
        #expect(abs(provider.currentSpeedMPH - 22.3694) < 1.0)
    }

    @Test func authorizationChangesWhenSimulating() async throws {
        let provider = LocationProvider()
        provider.startSimulation(
            origin: CLLocationCoordinate2D(latitude: 37.000, longitude: -122.000),
            destination: CLLocationCoordinate2D(latitude: 37.010, longitude: -122.010)
        )
        
        provider.locationManagerDidChangeAuthorization(CLLocationManager())
        
        #expect(provider.isSimulating == true)
    }
}
