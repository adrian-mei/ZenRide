import Testing
import Foundation
import SwiftData
import CoreLocation
@testable import ZenMap

// MARK: - Helpers

@MainActor private func makeStore() -> DriveStore {
    let schema = Schema([SavedRoute.self, DriveRecord.self, DriveSession.self, CameraZoneEvent.self])
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: schema, configurations: [config])
    return DriveStore(context: container.mainContext)
}
private func makeSession(
    date: Date = Date(),
    distanceMiles: Double = 5.0,
    durationSeconds: Int = 600,
    zenScore: Int = 80,
    timeOfDay: TimeOfDay = .midday
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
        timeOfDayCategory: timeOfDay,
        durationSeconds: durationSeconds,
        distanceMiles: distanceMiles,
        mood: nil,
        zenScore: zenScore
    )
}

private let originA = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

// MARK: - Tests

@MainActor
struct AchievementEngineTests {

    // Verify the engine produces exactly the 11 expected achievement IDs regardless of store state.
    @Test func achievementEngineReturnsExpectedIds() {
        let store = makeStore()
        let ids = Set(AchievementEngine.compute(from: store).map(\.id))
        let expected: Set<String> = [
            "rides_10", "rides_50", "zen_80", "night_5", "safe_10",
            "speed_80", "miles_100", "morning_5", "perfect_5", "streak_3", "save_500"
        ]
        #expect(ids == expected)
    }

    // Progress for rides_10 must equal min(1.0, totalRides / 10) — data-independent consistency check.
    @Test func ridesProgressMatchesStoreRideCount() {
        let store = makeStore()
        let achievements = AchievementEngine.compute(from: store)
        let rides10 = achievements.first { $0.id == "rides_10" }!
        let expected = min(1.0, Double(store.totalRideCount) / 10.0)
        #expect(abs(rides10.progress - expected) < 0.001)
    }

    // campRegularEarned when totalRideCount >= 10.
    @Test func campRegularEarnedAt10Rides() {
        let store = makeStore()
        for i in 0..<10 {
            let dest = CLLocationCoordinate2D(latitude: 37.8000 + Double(i) * 0.1, longitude: -122.4000)
            store.appendSession(originCoord: originA, destCoord: dest, destinationName: "AE_Place \(i)", session: makeSession())
        }
        let rides10 = AchievementEngine.compute(from: store).first { $0.id == "rides_10" }!
        #expect(rides10.isEarned == true)
    }

    // zen_80 isEarned must match the expected logic: avgZen >= 80 AND rides >= 10.
    @Test func zenAchievementReflectsRideCountCondition() {
        let store = makeStore()
        let achievements = AchievementEngine.compute(from: store)
        let zen80 = achievements.first { $0.id == "zen_80" }!
        let expectedEarned = store.avgZenScore >= 80 && store.totalRideCount >= 10
        #expect(zen80.isEarned == expectedEarned)
    }

    // nightOwlCountsNightSessions: after adding 5 night sessions night_5 must be earned.
    @Test func nightOwlCountsNightSessions() {
        let store = makeStore()
        for i in 0..<5 {
            let dest = CLLocationCoordinate2D(latitude: 37.8000 + Double(i) * 0.1, longitude: -122.4000)
            store.appendSession(originCoord: originA, destCoord: dest, destinationName: "AE_Night \(i)", session: makeSession(timeOfDay: .night))
        }
        let night5 = AchievementEngine.compute(from: store).first { $0.id == "night_5" }!
        #expect(night5.isEarned == true)
    }

    // earnedCount helper must equal manual filter count.
    @Test func earnedCountMatchesEarned() {
        let store = makeStore()
        let achievements = AchievementEngine.compute(from: store)
        let manualCount = achievements.filter(\.isEarned).count
        let helperCount = AchievementEngine.earnedCount(from: store)
        #expect(manualCount == helperCount)
    }
}
