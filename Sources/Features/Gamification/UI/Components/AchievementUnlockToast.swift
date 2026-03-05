import SwiftUI

public struct AchievementUnlockToast: View {
    public let achievement: Achievement
    @State private var appeared = false

    public init(achievement: Achievement) {
        self.achievement = achievement
    }

    public var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(achievement.color.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: achievement.icon)
                    .font(Theme.Typography.headline)
                    .foregroundColor(achievement.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("New Memento Collected!")
                    .font(Theme.Typography.caption)
                    .foregroundColor(achievement.color)
                    .kerning(0.5)
                Text(achievement.title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark)
                Text(achievement.subtitle)
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.acTextMuted)
            }

            Spacer()

            Image(systemName: "leaf.fill")
                .font(Theme.Typography.body)
                .foregroundColor(achievement.color)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Theme.Colors.acCream
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
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }
}
