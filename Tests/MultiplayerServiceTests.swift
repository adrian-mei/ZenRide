import Testing
import Foundation
import CoreLocation
@testable import ZenMap

@MainActor
struct MultiplayerServiceTests {

    @Test func inviteCode_nilWhenNoSession() {
        let service = MultiplayerService()
        #expect(service.inviteCode == nil)
    }

    @Test func inviteCode_sixCharsAfterSessionStarts() {
        let service = MultiplayerService()
        service.startHostingSession(
            destinationName: "Festival",
            destinationCoordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        )
        #expect(service.inviteCode?.count == 6)
    }

    @Test func inviteCode_isUppercased() {
        let service = MultiplayerService()
        service.startHostingSession(
            destinationName: "Festival",
            destinationCoordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        )
        guard let code = service.inviteCode else {
            Issue.record("inviteCode should not be nil after session starts")
            return
        }
        #expect(code.uppercased() == code)
    }

    @Test func inviteCode_derivedFromSessionId() {
        let service = MultiplayerService()
        service.startHostingSession(
            destinationName: "Festival",
            destinationCoordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        )
        guard let session = service.activeSession, let code = service.inviteCode else {
            Issue.record("session and inviteCode should be non-nil")
            return
        }
        #expect(String(session.id.prefix(6)).uppercased() == code)
    }

    @Test func endSession_clearsActiveSession() {
        let service = MultiplayerService()
        service.startHostingSession(
            destinationName: "Festival",
            destinationCoordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        )
        service.endSession()
        #expect(service.activeSession == nil)
        #expect(service.inviteCode == nil)
    }

    @Test func broadcastLocalLocation_silentWhenNoSession() {
        let service = MultiplayerService()
        // Should not crash when no session is active
        service.broadcastLocalLocation(
            coordinate: CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0),
            heading: 90,
            speedMph: 30,
            route: nil,
            etaSeconds: nil
        )
        #expect(service.activeSession == nil)
    }
}
