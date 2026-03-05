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
