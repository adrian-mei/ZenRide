import SwiftUI

struct MoodSelectionCard: View {
    var onSelect: (String) -> Void
    var onDismiss: () -> Void

    @State private var selectedMood: String?

    var body: some View {
        ACDialogueBox(speakerName: "Daily Log", speakerColor: Theme.Colors.acGold) {
            VStack(alignment: .leading, spacing: 16) {
                Text("How did that trip feel?")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)

                HStack(spacing: 10) {
                    MoodSelectionButton(emoji: "☀️", label: "Sunny", isSelected: selectedMood == "Sunny") { selectedMood = "Sunny" }
                    MoodSelectionButton(emoji: "🌧️", label: "Moody", isSelected: selectedMood == "Moody") { selectedMood = "Moody" }
                    MoodSelectionButton(emoji: "🎵", label: "Singing", isSelected: selectedMood == "Singing") { selectedMood = "Singing" }
                    MoodSelectionButton(emoji: "☕️", label: "Cozy", isSelected: selectedMood == "Cozy") { selectedMood = "Cozy" }
                }

                Button("Save to Journal") {
                    onSelect(selectedMood ?? "Cozy")
                }
                .buttonStyle(ACButtonStyle(variant: .primary))
                .padding(.top, 8)
            }
        }
        .padding()
    }
}

struct MoodSelectionButton: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            action()
        } label: {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 28))
                Text(label)
                    .font(Theme.Typography.label)
                    .foregroundColor(isSelected ? Theme.Colors.acTextDark : Theme.Colors.acTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Theme.Colors.acLeaf.opacity(0.15) : Theme.Colors.acField)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
