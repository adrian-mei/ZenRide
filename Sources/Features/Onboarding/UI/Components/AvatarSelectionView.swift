import SwiftUI

struct AvatarSelectionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var playerStore: PlayerStore

    let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        Text("Choose Your Character")
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .padding(.top, 16)

                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(Character.all) { character in
                                let isUnlocked = character.unlockLevel <= playerStore.currentLevel
                                let isSelected = character.id == playerStore.selectedCharacterId

                                Button {
                                    if isUnlocked {
                                        UISelectionFeedbackGenerator().selectionChanged()
                                        playerStore.selectCharacter(character)
                                    } else {
                                        UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                                    }
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(isUnlocked ? Color(hex: character.colorHex).opacity(0.15) : Theme.Colors.acCream)
                                                .frame(width: 72, height: 72)
                                                .overlay(
                                                    Circle().stroke(
                                                        isSelected ? Color(hex: character.colorHex) : Theme.Colors.acBorder,
                                                        lineWidth: isSelected ? 4 : 2
                                                    )
                                                )

                                            if isUnlocked {
                                                Image(systemName: character.icon)
                                                    .font(.system(size: 32))
                                                    .foregroundColor(Color(hex: character.colorHex))
                                            } else {
                                                Image(systemName: "lock.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(Theme.Colors.acTextMuted)
                                            }
                                        }

                                        VStack(spacing: 2) {
                                            Text(character.name)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(isUnlocked ? Theme.Colors.acTextDark : Theme.Colors.acTextMuted)

                                            if !isUnlocked {
                                                Text("Lv \(character.unlockLevel)")
                                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                                    .foregroundColor(Theme.Colors.acWood)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity)
                                    .background(isSelected ? Color(hex: character.colorHex).opacity(0.05) : Color.clear)
                                    .cornerRadius(16)
                                    .scaleEffect(isSelected ? 1.05 : 1.0)
                                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.bold())
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
    }
}
