import SwiftUI

public struct AchievementBadge: View {
    public let achievement: Achievement
    public var size: CGFloat = 64

    @State private var glowPulse = false

    public init(achievement: Achievement, size: CGFloat = 64) {
        self.achievement = achievement
        self.size = size
    }

    public var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        achievement.isEarned
                            ? RadialGradient(colors: [achievement.color.opacity(0.4), achievement.color.opacity(0.1)], center: .center, startRadius: 0, endRadius: size / 2)
                            : RadialGradient(colors: [Theme.Colors.acBorder.opacity(0.2), Color.clear], center: .center, startRadius: 0, endRadius: size / 2)
                    )
                    .frame(width: size, height: size)
                    .overlay(
                        Circle()
                            .strokeBorder(
                                achievement.isEarned
                                    ? achievement.color.opacity(glowPulse ? 0.9 : 0.5)
                                    : Theme.Colors.acBorder.opacity(0.5),
                                lineWidth: achievement.isEarned ? 1.5 : 1
                            )
                    )
                    .shadow(
                        color: achievement.isEarned ? achievement.color.opacity(0.3) : .clear,
                        radius: 8, x: 0, y: 0
                    )

                Image(systemName: achievement.icon)
                    .font(.system(size: size * 0.36, weight: .bold))
                    .foregroundColor(achievement.isEarned ? achievement.color : Theme.Colors.acBorder.opacity(0.8))
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
                            .font(Theme.Typography.label)
                            .foregroundColor(achievement.color.opacity(0.9))
                            .padding(.bottom, 5)
                    }
                    .frame(width: size, height: size)
                }
            }

            Text(achievement.title)
                .font(Theme.Typography.label)
                .foregroundColor(achievement.isEarned ? Theme.Colors.acTextDark : Theme.Colors.acTextMuted.opacity(0.6))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(width: size + 8)
                .opacity(achievement.isEarned ? 1.0 : 0.6)
        }
        .onAppear {
            guard achievement.isEarned else { return }
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}
