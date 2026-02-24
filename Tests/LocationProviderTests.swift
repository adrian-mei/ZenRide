import Testing
import Foundation
import CoreLocation
@testable import ZenRide

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
        
        // Since simulateDrive sets state on main queue, wait a bit
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 sec
        
        #expect(provider.isSimulating == true)
        #expect(provider.simulationCompletedNaturally == false)
        
        // Manually stop simulation to test stop lifecycle
        provider.stopSimulation()
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(provider.isSimulating == false)
        #expect(provider.currentSimulationIndex == 0)
        #expect(provider.distanceTraveledInSimulationMeters == 0)
    }

}
