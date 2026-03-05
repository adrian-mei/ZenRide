import Testing
import Foundation
import CoreLocation
@testable import ZenMap

// MARK: - Helpers

private let zeroCoord = CLLocationCoordinate2D(latitude: 0, longitude: 0)

private func makePending(
    events: [CameraZoneEvent] = [],
    actual: Int = 600,
    route: Int = 600
) -> PendingDriveSession {
    PendingDriveSession(
        speedReadings: [],
        cameraZoneEvents: events,
        topSpeedMph: 0,
        avgSpeedMph: 0,
        zenScore: 0,
        departureTime: Date(),
        actualDurationSeconds: actual,
        distanceMiles: 0,
        originCoord: zeroCoord,
        destCoord: zeroCoord,
        destinationName: "Test",
        routeDurationSeconds: route
    )
}

private func makeSavedEvent() -> CameraZoneEvent {
    CameraZoneEvent(
        cameraId: "cam",
        cameraStreet: "St",
        speedLimitMph: 30,
        userSpeedAtZone: 28,
        didSlowDown: true,
        outcome: .saved
    )
}

// MARK: - Tests

struct PendingDriveSessionTests {

    @Test func toSession_noEvents_moneySavedIsZero() {
        let session = makePending(events: []).toSession()
        #expect(session.moneySaved == 0)
    }

    @Test func toSession_twoSaved_moneySavedIs200() {
        let events = [makeSavedEvent(), makeSavedEvent()]
        let session = makePending(events: events).toSession()
        #expect(session.moneySaved == 200)
    }

    @Test func toSession_trafficDelay_zeroWhenActualLessOrEqual() {
        let session = makePending(actual: 500, route: 600).toSession()
        #expect(session.trafficDelaySeconds == 0)
    }

    @Test func toSession_trafficDelay_correctWhenActualGreater() {
        let session = makePending(actual: 700, route: 600).toSession()
        #expect(session.trafficDelaySeconds == 100)
    }
}
