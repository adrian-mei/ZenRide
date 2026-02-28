import SwiftUI

// MARK: - Achievement

struct Achievement: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let isEarned: Bool
    let progress: Double   // 0–1, for partially earned badges
}

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
                color: .yellow,
                isEarned: totalRides >= 10,
                progress: min(1.0, Double(totalRides) / 10.0)
            ),
            Achievement(
                id: "zen_80",
                title: "Gentle Breeze",
                subtitle: "Avg Zen Score ≥ 80 over 10 rides",
                icon: "leaf.fill",
                color: .green,
                isEarned: avgZen >= 80 && totalRides >= 10,
                progress: totalRides == 0 ? 0 : min(1.0, Double(avgZen) / 80.0)
            ),
            Achievement(
                id: "night_5",
                title: "Midnight Owl",
                subtitle: "5 night rides",
                icon: "moon.stars.fill",
                color: .purple,
                isEarned: nightRides >= 5,
                progress: min(1.0, Double(nightRides) / 5.0)
            ),
            Achievement(
                id: "safe_10",
                title: "Smooth Glider",
                subtitle: "Avoid 10 speed cameras",
                icon: "wind",
                color: .cyan,
                isEarned: savedCameras >= 10,
                progress: min(1.0, Double(savedCameras) / 10.0)
            ),
            Achievement(
                id: "speed_80",
                title: "Tailwind Chaser",
                subtitle: "Experience a brisk ride over 80 mph",
                icon: "hare.fill",
                color: .orange,
                isEarned: topSpeed > 80,
                progress: min(1.0, topSpeed / 80.0)
            ),
            Achievement(
                id: "miles_100",
                title: "Wilderness Explorer",
                subtitle: "Ride 100+ miles total",
                icon: "map.fill",
                color: .blue,
                isEarned: totalMiles >= 100,
                progress: min(1.0, totalMiles / 100.0)
            ),
            Achievement(
                id: "morning_5",
                title: "Morning Dew",
                subtitle: "5 early morning rides",
                icon: "sunrise.fill",
                color: Color(red: 1, green: 0.7, blue: 0.2),
                isEarned: morningRides >= 5,
                progress: min(1.0, Double(morningRides) / 5.0)
            ),
            Achievement(
                id: "perfect_5",
                title: "Silent Shadow",
                subtitle: "5 rides with zero camera incidents",
                icon: "moon.fill",
                color: Color(red: 0.5, green: 0.1, blue: 0.9),
                isEarned: perfectRideCount >= 5,
                progress: min(1.0, Double(perfectRideCount) / 5.0)
            ),
            Achievement(
                id: "streak_3",
                title: "Warm Hearth",
                subtitle: "Keep the camp lit 3 days in a row",
                icon: "flame.fill",
                color: .red,
                isEarned: streak >= 3,
                progress: min(1.0, Double(streak) / 3.0)
            ),
            Achievement(
                id: "save_500",
                title: "Wise Forager",
                subtitle: "Save $500+ in potential fines",
                icon: "leaf.circle.fill",
                color: Color(red: 0.1, green: 0.8, blue: 0.4),
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

struct AchievementBadge: View {
    let achievement: Achievement
    var size: CGFloat = 64

    @State private var glowPulse = false

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        achievement.isEarned
                            ? RadialGradient(colors: [achievement.color.opacity(0.4), achievement.color.opacity(0.1)], center: .center, startRadius: 0, endRadius: size / 2)
                            : RadialGradient(colors: [Color.white.opacity(0.05), Color.clear], center: .center, startRadius: 0, endRadius: size / 2)
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                achievement.isEarned
                                    ? achievement.color.opacity(glowPulse ? 0.9 : 0.5)
                                    : Color.white.opacity(0.12),
                                lineWidth: achievement.isEarned ? 1.5 : 1
                            )
                    )
                    .shadow(
                        color: achievement.isEarned ? achievement.color.opacity(0.3) : .clear,
                        radius: 8, x: 0, y: 0
                    )

                Image(systemName: achievement.icon)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundColor(achievement.isEarned ? achievement.color : .white.opacity(0.2))
                    .shadow(color: achievement.isEarned ? achievement.color.opacity(0.6) : .clear, radius: 4)

                // Progress arc — thicker, brighter, with % label
                if !achievement.isEarned && achievement.progress > 0 {
                    // Track
                    Circle()
                        .stroke(achievement.color.opacity(0.1), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: size - 4, height: size - 4)

                    // Fill
                    Circle()
                        .trim(from: 0, to: achievement.progress)
                        .stroke(achievement.color.opacity(0.65), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: size - 4, height: size - 4)
                        .rotationEffect(.degrees(-90))
                        .shadow(color: achievement.color.opacity(0.4), radius: 3)

                    // Percentage label at bottom of circle
                    VStack {
                        Spacer()
                        Text("\(Int(achievement.progress * 100))%")
                            .font(.system(size: 7, weight: .black, design: .monospaced))
                            .foregroundColor(achievement.color.opacity(0.9))
                            .padding(.bottom, 5)
                    }
                    .frame(width: size, height: size)
                }
            }

            Text(achievement.title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(achievement.isEarned ? .white : .white.opacity(0.3))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: size + 8)
        }
        .onAppear {
            guard achievement.isEarned else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Achievement Unlock Toast

struct AchievementUnlockToast: View {
    let achievement: Achievement
    @State private var appeared = false

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(achievement.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(achievement.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("New Memento Collected!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(achievement.color)
                    .kerning(0.5)
                Text(achievement.title)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text(achievement.subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "leaf.fill")
                .font(.system(size: 16))
                .foregroundColor(achievement.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.1)
                achievement.color.opacity(0.08)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(achievement.color.opacity(0.4), lineWidth: 1))
        .shadow(color: achievement.color.opacity(0.25), radius: 12, x: 0, y: 4)
        .padding(.horizontal, 16)
        .scaleEffect(appeared ? 1 : 0.85)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}

// MARK: - Achievements Shelf

struct AchievementsShelf: View {
    @EnvironmentObject var driveStore: DriveStore

    private var achievements: [Achievement] {
        AchievementEngine.compute(from: driveStore)
    }

    private var earnedCount: Int {
        achievements.filter(\.isEarned).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MEMENTOS")
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(.white.opacity(0.5))
                        .kerning(1.5)
                    Text("\(earnedCount) of \(achievements.count) collected")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                Spacer()

                // Progress bar (No XP)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Collection")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.green.opacity(0.8))
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1)).frame(height: 4)
                            Capsule()
                                .fill(LinearGradient(colors: [.green, .cyan], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * Double(earnedCount) / Double(max(achievements.count, 1)), height: 4)
                        }
                    }
                    .frame(width: 80, height: 4)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // Earned first, then locked
                    ForEach(achievements.filter(\.isEarned)) { badge in
                        AchievementBadge(achievement: badge, size: 60)
                    }
                    if achievements.filter(\.isEarned).count < achievements.count {
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 1, height: 60)
                        ForEach(achievements.filter { !$0.isEarned }) { badge in
                            AchievementBadge(achievement: badge, size: 60)
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 4)
            }
        }
    }
}
