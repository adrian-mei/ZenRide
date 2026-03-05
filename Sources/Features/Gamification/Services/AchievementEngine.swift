import SwiftUI

// MARK: - Achievement


// MARK: - Achievement Engine

@MainActor
struct AchievementEngine {

    static func compute(from store: DriveStore) -> [Achievement] {
        let sessions   = store.records.flatMap(\.sessions)
        let totalRides = store.totalRideCount
        let totalMiles = store.totalDistanceMiles
        let avgZen     = store.avgZenScore
        let topSpeed   = store.allTimeTopSpeedMph
        let streak     = store.currentStreak

        let nightRides   = sessions.filter { $0.timeOfDayCategory == .night }.count
        let morningRides = sessions.filter { $0.timeOfDayCategory == .morningCommute }.count

        let allEvents       = sessions.flatMap(\.cameraZoneEvents)
        let savedCameras    = allEvents.filter { $0.outcome == .saved }.count
        let perfectRideCount = sessions.filter { $0.cameraZoneEvents.allSatisfy { $0.outcome == .saved } && !$0.cameraZoneEvents.isEmpty }.count

        return [
            Achievement(
                id: "rides_10",
                title: "Camp Regular",
                subtitle: "Complete 10 rides",
                icon: "tent.fill",
                color: Theme.Colors.acGold,
                isEarned: totalRides >= 10,
                progress: min(1.0, Double(totalRides) / 10.0)
            ),
            Achievement(
                id: "rides_50",
                title: "Dedicated Commuter",
                subtitle: "Complete 50 rides",
                icon: "car.fill",
                color: Theme.Colors.acCoral,
                isEarned: totalRides >= 50,
                progress: min(1.0, Double(totalRides) / 50.0)
            ),
            Achievement(
                id: "zen_80",
                title: "Gentle Breeze",
                subtitle: "Avg Zen Score ≥ 80 over 10 rides",
                icon: "leaf.fill",
                color: Theme.Colors.acLeaf,
                isEarned: avgZen >= 80 && totalRides >= 10,
                progress: totalRides == 0 ? 0 : min(1.0, Double(avgZen) / 80.0)
            ),
            Achievement(
                id: "night_5",
                title: "Midnight Owl",
                subtitle: "5 night rides",
                icon: "moon.stars.fill",
                color: Theme.Colors.acLavender,
                isEarned: nightRides >= 5,
                progress: min(1.0, Double(nightRides) / 5.0)
            ),
            Achievement(
                id: "safe_10",
                title: "Smooth Glider",
                subtitle: "Avoid 10 speed cameras",
                icon: "wind",
                color: Theme.Colors.acMint,
                isEarned: savedCameras >= 10,
                progress: min(1.0, Double(savedCameras) / 10.0)
            ),
            Achievement(
                id: "speed_80",
                title: "Tailwind Chaser",
                subtitle: "Experience a brisk ride over 80 mph",
                icon: "hare.fill",
                color: Theme.Colors.acWood,
                isEarned: topSpeed > 80,
                progress: min(1.0, topSpeed / 80.0)
            ),
            Achievement(
                id: "miles_100",
                title: "Wilderness Explorer",
                subtitle: "Ride 100+ miles total",
                icon: "map.fill",
                color: Theme.Colors.acSky,
                isEarned: totalMiles >= 100,
                progress: min(1.0, totalMiles / 100.0)
            ),
            Achievement(
                id: "morning_5",
                title: "Morning Dew",
                subtitle: "5 early morning rides",
                icon: "sunrise.fill",
                color: Theme.Colors.acGold,
                isEarned: morningRides >= 5,
                progress: min(1.0, Double(morningRides) / 5.0)
            ),
            Achievement(
                id: "perfect_5",
                title: "Silent Shadow",
                subtitle: "5 rides with zero camera incidents",
                icon: "moon.fill",
                color: Theme.Colors.acLavender,
                isEarned: perfectRideCount >= 5,
                progress: min(1.0, Double(perfectRideCount) / 5.0)
            ),
            Achievement(
                id: "streak_3",
                title: "Warm Hearth",
                subtitle: "Keep the camp lit 3 days in a row",
                icon: "flame.fill",
                color: Theme.Colors.acError,
                isEarned: streak >= 3,
                progress: min(1.0, Double(streak) / 3.0)
            ),
            Achievement(
                id: "save_500",
                title: "Wise Forager",
                subtitle: "Save $500+ in potential fines",
                icon: "leaf.circle.fill",
                color: Theme.Colors.acGrass,
                isEarned: store.totalSavedAllTime >= 500,
                progress: min(1.0, store.totalSavedAllTime / 500.0)
            )
        ]
    }

    @MainActor static func earnedCount(from store: DriveStore) -> Int {
        compute(from: store).filter(\.isEarned).count
    }

    @MainActor static func recentlyEarned(from store: DriveStore, previous earnedCount: Int) -> Achievement? {
        let all = compute(from: store)
        let nowCount = all.filter(\.isEarned).count
        guard nowCount > earnedCount else { return nil }
        return all.filter(\.isEarned).last
    }
}

// MARK: - Achievement Badge View

