import SwiftUI

struct RiderStatsBanner: View {
    @EnvironmentObject var driveStore: DriveStore

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                let streak = driveStore.currentStreak
                ACStatBox(
                    title: "Day Streak",
                    value: "\(streak)",
                    icon: streak > 0 ? "flame.fill" : "flame",
                    iconColor: streak > 0 ? Theme.Colors.acCoral : Theme.Colors.acTextMuted,
                    padding: 12
                )
                ACStatBox(
                    title: "Miles",
                    value: String(format: "%.0f", driveStore.totalDistanceMiles),
                    icon: "map.fill",
                    iconColor: Theme.Colors.acSky,
                    padding: 12
                )
            }
            HStack(spacing: 12) {
                ACStatBox(
                    title: "Avg Score",
                    value: String(format: "%.0f", driveStore.avgZenScore),
                    icon: "star.circle.fill",
                    iconColor: Theme.Colors.acGold,
                    padding: 12
                )
                ACStatBox(
                    title: "Saved",
                    value: "$\(Int(driveStore.totalSavedAllTime))",
                    icon: "leaf.circle.fill",
                    iconColor: Theme.Colors.acLeaf,
                    padding: 12
                )
            }
        }
    }
}
