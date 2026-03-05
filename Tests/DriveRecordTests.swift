import Testing
import Foundation
@testable import ZenMap

// MARK: - Helpers

private func makeCameraEvent(outcome: CameraOutcome) -> CameraZoneEvent {
    CameraZoneEvent(
        cameraId: "cam_test",
        cameraStreet: "Test St",
        speedLimitMph: 30,
        userSpeedAtZone: outcome == .saved ? 28 : 40,
        didSlowDown: outcome == .saved,
        outcome: outcome
    )
}

private func makeSession(cameraZoneEvents: [CameraZoneEvent] = []) -> DriveSession {
    DriveSession(
        date: Date(),
        departureHour: 10,
        avgSpeedMph: 30,
        topSpeedMph: 50,
        speedReadings: [],
        cameraZoneEvents: cameraZoneEvents,
        moneySaved: 0,
        trafficDelaySeconds: 0,
        timeOfDayCategory: .midday,
        durationSeconds: 600,
        distanceMiles: 5,
        mood: nil,
        zenScore: 80
    )
}

// MARK: - TimeOfDay tests

struct TimeOfDayTests {

    @Test func hour5_isNight() {
        #expect(TimeOfDay.from(hour: 5) == .night)
    }

    @Test func hour6_isMorningCommute() {
        #expect(TimeOfDay.from(hour: 6) == .morningCommute)
    }

    @Test func hour8_isMorningCommute() {
        #expect(TimeOfDay.from(hour: 8) == .morningCommute)
    }

    @Test func hour9_isMidday() {
        #expect(TimeOfDay.from(hour: 9) == .midday)
    }

    @Test func hour15_isMidday() {
        #expect(TimeOfDay.from(hour: 15) == .midday)
    }

    @Test func hour16_isEveningCommute() {
        #expect(TimeOfDay.from(hour: 16) == .eveningCommute)
    }

    @Test func hour18_isEveningCommute() {
        #expect(TimeOfDay.from(hour: 18) == .eveningCommute)
    }

    @Test func hour19_isNight() {
        #expect(TimeOfDay.from(hour: 19) == .night)
    }

    @Test func hour23_isNight() {
        #expect(TimeOfDay.from(hour: 23) == .night)
    }

    @Test func allCasesHaveNonEmptyLabel() {
        #expect(!TimeOfDay.morningCommute.label.isEmpty)
        #expect(!TimeOfDay.midday.label.isEmpty)
        #expect(!TimeOfDay.eveningCommute.label.isEmpty)
        #expect(!TimeOfDay.night.label.isEmpty)
    }
}

// MARK: - CameraZoneEvent tests

struct CameraZoneEventTests {

    @Test func moneySaved_savedOutcome_returns100() {
        let event = makeCameraEvent(outcome: .saved)
        #expect(event.moneySaved == 100)
    }

    @Test func moneySaved_potentialTicketOutcome_returnsZero() {
        let event = makeCameraEvent(outcome: .potentialTicket)
        #expect(event.moneySaved == 0)
    }
}

// MARK: - DriveSession tests

struct DriveSessionTests {

    @Test func savedCameraCount_noEvents_returnsZero() {
        let session = makeSession(cameraZoneEvents: [])
        #expect(session.savedCameraCount == 0)
    }

    @Test func savedCameraCount_mixedEvents_countsOnlySaved() {
        let events = [
            makeCameraEvent(outcome: .saved),
            makeCameraEvent(outcome: .saved),
            makeCameraEvent(outcome: .potentialTicket)
        ]
        let session = makeSession(cameraZoneEvents: events)
        #expect(session.savedCameraCount == 2)
    }

    @Test func potentialTicketCount_mixedEvents_countsOnlyTickets() {
        let events = [
            makeCameraEvent(outcome: .saved),
            makeCameraEvent(outcome: .saved),
            makeCameraEvent(outcome: .potentialTicket)
        ]
        let session = makeSession(cameraZoneEvents: events)
        #expect(session.potentialTicketCount == 1)
    }
}

// MARK: - DriveRecord aggregate tests

private func makeAggSession(avg: Double, top: Double, money: Double, dist: Double, duration: Int) -> DriveSession {
    DriveSession(
        date: Date(),
        departureHour: 10,
        avgSpeedMph: avg,
        topSpeedMph: top,
        speedReadings: [],
        cameraZoneEvents: [],
        moneySaved: money,
        trafficDelaySeconds: 0,
        timeOfDayCategory: .midday,
        durationSeconds: duration,
        distanceMiles: dist,
        mood: nil,
        zenScore: 80
    )
}

private func makeRecord(sessions: [DriveSession]) -> DriveRecord {
    DriveRecord(
        routeFingerprint: "test",
        destinationName: "Test",
        originLatitude: 0,
        originLongitude: 0,
        destinationLatitude: 0,
        destinationLongitude: 0,
        sessions: sessions
    )
}

struct DriveRecordAggregateTests {

    @Test func noSessions_allAggregatesAreZero() {
        let record = makeRecord(sessions: [])
        #expect(record.allTimeAvgSpeedMph == 0)
        #expect(record.allTimeTopSpeedMph == 0)
        #expect(record.allTimeMoneySaved == 0)
        #expect(record.totalDistanceMiles == 0)
        #expect(record.totalTimeDrivenSeconds == 0)
    }

    @Test func singleSession_aggregatesMatchSession() {
        let session = makeAggSession(avg: 40, top: 60, money: 100, dist: 5, duration: 600)
        let record = makeRecord(sessions: [session])
        #expect(record.allTimeAvgSpeedMph == 40)
        #expect(record.allTimeTopSpeedMph == 60)
        #expect(record.allTimeMoneySaved == 100)
        #expect(record.totalDistanceMiles == 5)
        #expect(record.totalTimeDrivenSeconds == 600)
    }

    @Test func twoSessions_avgSpeedIsSimpleAverage() {
        let s1 = makeAggSession(avg: 40, top: 50, money: 0, dist: 0, duration: 0)
        let s2 = makeAggSession(avg: 60, top: 50, money: 0, dist: 0, duration: 0)
        let record = makeRecord(sessions: [s1, s2])
        #expect(record.allTimeAvgSpeedMph == 50.0)
    }

    @Test func twoSessions_topSpeedIsMax() {
        let s1 = makeAggSession(avg: 30, top: 40, money: 0, dist: 0, duration: 0)
        let s2 = makeAggSession(avg: 30, top: 60, money: 0, dist: 0, duration: 0)
        let record = makeRecord(sessions: [s1, s2])
        #expect(record.allTimeTopSpeedMph == 60.0)
    }

    @Test func twoSessions_moneySavedAndDistanceSummed() {
        let s1 = makeAggSession(avg: 30, top: 50, money: 100, dist: 3, duration: 300)
        let s2 = makeAggSession(avg: 30, top: 50, money: 200, dist: 7, duration: 500)
        let record = makeRecord(sessions: [s1, s2])
        #expect(record.allTimeMoneySaved == 300)
        #expect(record.totalDistanceMiles == 10)
    }
}
