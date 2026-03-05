import SwiftUI

public struct AchievementsShelf: View {
    @EnvironmentObject var driveStore: DriveStore

    private var achievements: [Achievement] {
        AchievementEngine.compute(from: driveStore)
    }

    private var earnedCount: Int {
        achievements.filter(\.isEarned).count
    }

    public init() {}

    public var body: some View {
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
