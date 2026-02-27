import Testing
import Foundation
import CoreLocation
@testable import FashodaMap

@MainActor
struct BunnyPoliceTests {

    @Test func testZoneTransitionsAndZenScore() async throws {
        let service = BunnyPolice()
        
        let camera = SpeedCamera(
            id: "cam-1",
            street: "Main St",
            from_cross_street: nil,
            to_cross_street: nil,
            speed_limit_mph: 30,
            lat: 37.0,
            lng: -122.0
        )
        service.cameras = [camera]
        service.startNavigationSession()
        
        var loc = CLLocation(latitude: 37.01, longitude: -122.0)
        service.processLocation(loc, speedMPH: 35)
        
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(service.currentZone == .safe)
        
        loc = CLLocation(latitude: 37.002, longitude: -122.0)
        service.processLocation(loc, speedMPH: 35)
        
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(service.currentZone == .approach)
        
        loc = CLLocation(latitude: 37.0008, longitude: -122.0)
        service.processLocation(loc, speedMPH: 40)
        
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(service.currentZone == .danger)
        #expect(service.zenScore == 95)
        
        loc = CLLocation(latitude: 37.0004, longitude: -122.0)
        service.processLocation(loc, speedMPH: 28)
        
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(service.currentZone == .danger)
        
        loc = CLLocation(latitude: 36.99, longitude: -122.0)
        service.processLocation(loc, speedMPH: 35)
        
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(service.currentZone == .safe)
        #expect(service.camerasPassedThisRide == 1)
        
        service.stopNavigationSession()
        
        #expect(service.cameraZoneEvents.count == 1)
        #expect(service.cameraZoneEvents.first?.outcome == .saved)
    }

}
