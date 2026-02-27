import Testing
import Foundation
import CoreLocation
@testable import FashodaMap

@MainActor
struct LocationProviderTests {

    @Test func simulationLifecycle() async throws {
        let provider = LocationProvider()
        
        let startCoord = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let endCoord = CLLocationCoordinate2D(latitude: 37.001, longitude: -122.0) // ~111 meters North
        let route = [startCoord, endCoord]
        
        // Ensure starting state
        #expect(provider.isSimulating == false)
        #expect(provider.simulationCompletedNaturally == false)
        #expect(provider.currentSimulationIndex == 0)
        
        provider.simulateDrive(along: route)
        
        // Wait a bit longer for main queue
        try await Task.sleep(nanoseconds: 200_000_000) 
        
        #expect(provider.isSimulating == true)
        #expect(provider.simulationCompletedNaturally == false)
        
        // Manually stop simulation to test stop lifecycle
        provider.stopSimulation()
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(provider.isSimulating == false)
        #expect(provider.currentSimulationIndex == 0)
        #expect(provider.distanceTraveledInSimulationMeters == 0)
    }

    @Test func ignoredLiveUpdatesWhenSimulating() async throws {
        let provider = LocationProvider()
        provider.isSimulating = true
        
        let loc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 10), altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 10, timestamp: Date())
        
        provider.locationManager(CLLocationManager(), didUpdateLocations: [loc])
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(provider.currentLocation == nil)
        #expect(provider.currentSpeedMPH == 0)
    }

    @Test func invalidRoutesForSimulation() async throws {
        let provider = LocationProvider()
        
        provider.simulateDrive(along: [])
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(provider.isSimulating == false)
        
        provider.simulateDrive(along: [CLLocationCoordinate2D(latitude: 10, longitude: 10)])
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(provider.isSimulating == false)
    }

    @Test func speedConversion() async throws {
        let provider = LocationProvider()
        provider.isSimulating = false
        
        // 10 m/s = 22.3694 mph
        let loc = CLLocation(coordinate: CLLocationCoordinate2D(latitude: 10, longitude: 10), altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5, course: 0, speed: 10, timestamp: Date())
        
        provider.locationManager(CLLocationManager(), didUpdateLocations: [loc])
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(provider.currentLocation != nil)
        #expect(abs(provider.currentSpeedMPH - 22.3694) < 0.001)
    }

    @Test func authorizationChangesWhenSimulating() async throws {
        let provider = LocationProvider()
        provider.isSimulating = true
        
        let manager = CLLocationManager()
        provider.locationManagerDidChangeAuthorization(manager)
        
        #expect(provider.isSimulating == true)
    }
}
