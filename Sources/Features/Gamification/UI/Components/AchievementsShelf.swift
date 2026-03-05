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
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.acWood)
                        .kerning(1.5)
                    Text("\(earnedCount) of \(achievements.count) collected")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                Spacer()

                // Progress bar (No XP)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Collection")
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.acLeaf)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Colors.acBorder.opacity(0.3)).frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(colors: [Theme.Colors.acLeaf, Theme.Colors.acSky], startPoint: .leading, endPoint: .trailing))
                                .frame(width: geo.size.width * Double(earnedCount) / Double(max(achievements.count, 1)), height: 6)
                        }
                    }
                    .frame(width: 80, height: 6)
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
                            .fill(Theme.Colors.acBorder.opacity(0.3))
                            .frame(width: 2, height: 60)
                            .clipShape(Capsule())
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
