import SwiftUI

struct ModeSelector: View {
    @EnvironmentObject var playerStore: PlayerStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(ZenMode.allCases, id: \.self) { mode in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            playerStore.currentMode = mode
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: mode.icon)
                                .font(.system(size: 14, weight: .bold))
                            Text(mode.displayName)
                                .font(Theme.Typography.button)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(playerStore.currentMode == mode ? Theme.Colors.acLeaf : Theme.Colors.acField)
                        .foregroundColor(playerStore.currentMode == mode ? .white : Theme.Colors.acTextDark)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.Colors.acBorder, lineWidth: 2))
                        .shadow(color: Theme.Colors.acBorder.opacity(0.3), radius: 0, x: 0, y: 3)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}
