import Testing
import Foundation
import CoreLocation
@testable import ZenRide

// MARK: - Helpers

private func makeSession(
    date: Date = Date(),
    distanceMiles: Double = 5.0,
    durationSeconds: Int = 600,
    zenScore: Int = 80
) -> DriveSession {
    DriveSession(
        date: date,
        departureHour: Calendar.current.component(.hour, from: date),
        avgSpeedMph: 30,
        topSpeedMph: 55,
        speedReadings: [],
        cameraZoneEvents: [],
        moneySaved: 0,
        trafficDelaySeconds: 0,
        timeOfDayCategory: .midday,
        durationSeconds: durationSeconds,
        distanceMiles: distanceMiles,
        mood: nil,
        zenScore: zenScore
    )
}

private let originA = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
private let destA   = CLLocationCoordinate2D(latitude: 37.8000, longitude: -122.4000)
private let destB   = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437) // far away

private func makeStore() -> DriveStore {
    let suite = UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    return DriveStore(defaults: defaults)
}

// MARK: - Tests

struct DriveStoreTests {

    @Test func appendCreatesNewRecord() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        #expect(store.records.count == 1)
        #expect(store.records[0].destinationName == "Park")
    }

    @Test func appendDeduplicatesByFingerprint() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        #expect(store.records.count == 1)
        #expect(store.records[0].sessionCount == 2)
    }

    @Test func appendDifferentCoordsCreatesSeparateRecords() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        store.appendSession(originCoord: originA, destCoord: destB, destinationName: "Downtown LA", session: makeSession())
        #expect(store.records.count == 2)
    }

    @Test func fingerprintSnapsTo500mGrid() {
        // Two coords within ~400m of each other should snap to same fingerprint
        let coord1 = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let coord2 = CLLocationCoordinate2D(latitude: 37.7751, longitude: -122.4196)
        let fp1 = DriveStore.makeFingerprint(origin: coord1, dest: coord1)
        let fp2 = DriveStore.makeFingerprint(origin: coord2, dest: coord2)
        #expect(fp1 == fp2)
    }

    @Test func toggleBookmarkMarksRecord() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        let id = store.records[0].id
        store.toggleBookmark(id: id)
        #expect(store.records[0].isBookmarked == true)
    }

    @Test func toggleBookmarkUnmarksRecord() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        let id = store.records[0].id
        store.toggleBookmark(id: id)
        store.toggleBookmark(id: id)
        #expect(store.records[0].isBookmarked == false)
    }

    @Test func bookmarkedRecordsOnlyReturnsBookmarked() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        store.appendSession(originCoord: originA, destCoord: destB, destinationName: "LA", session: makeSession())
        store.toggleBookmark(id: store.records[0].id)
        #expect(store.bookmarkedRecords.count == 1)
        #expect(store.bookmarkedRecords[0].destinationName == "Park")
    }

    @Test func deleteRecordRemovesFromArray() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        let id = store.records[0].id
        store.deleteRecord(id: id)
        #expect(store.records.isEmpty)
    }

    @Test func totalRideCountSumsAllSessions() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession())
        store.appendSession(originCoord: originA, destCoord: destB, destinationName: "LA", session: makeSession())
        #expect(store.totalRideCount == 3)
    }

    @Test func totalDistanceMilesSumsAcrossRecords() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(distanceMiles: 3.0))
        store.appendSession(originCoord: originA, destCoord: destB, destinationName: "LA", session: makeSession(distanceMiles: 7.0))
        #expect(abs(store.totalDistanceMiles - 10.0) < 0.001)
    }

    @Test func avgZenScoreAverages() {
        let store = makeStore()
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(zenScore: 60))
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(zenScore: 80))
        // (60 + 80) / 2 = 70
        #expect(store.avgZenScore == 70)
    }

    @Test func currentStreakCountsConsecutiveDays() {
        let store = makeStore()
        let calendar = Calendar.current
        let today = Date()
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(date: today))
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(date: yesterday))
        #expect(store.currentStreak == 2)
    }

    @Test func currentStreakBreaksOnGap() {
        let store = makeStore()
        let calendar = Calendar.current
        let today = Date()
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: today)!
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(date: today))
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(date: twoDaysAgo))
        #expect(store.currentStreak == 1)
    }

    @Test func todayMilesOnlyCountsToday() {
        let store = makeStore()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(date: Date(), distanceMiles: 4.0))
        store.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(date: yesterday, distanceMiles: 10.0))
        #expect(abs(store.todayMiles - 4.0) < 0.001)
    }

    @Test func persistenceRoundTrip() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = DriveStore(defaults: defaults)
        store1.appendSession(originCoord: originA, destCoord: destA, destinationName: "Park", session: makeSession(distanceMiles: 5.5, zenScore: 90))
        store1.toggleBookmark(id: store1.records[0].id)

        let store2 = DriveStore(defaults: defaults)
        #expect(store2.records.count == 1)
        #expect(store2.records[0].destinationName == "Park")
        #expect(store2.records[0].isBookmarked == true)
        #expect(abs(store2.records[0].totalDistanceMiles - 5.5) < 0.001)
    }
}
