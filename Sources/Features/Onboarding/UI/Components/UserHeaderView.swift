import SwiftUI

struct UserHeaderView: View {
    let name: String
    let email: String
    let subscription: String
    @EnvironmentObject var driveStore: DriveStore
    @EnvironmentObject var playerStore: PlayerStore

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color(hex: playerStore.selectedCharacter.colorHex).opacity(0.2))
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Color(hex: playerStore.selectedCharacter.colorHex), lineWidth: 2))
                Image(systemName: playerStore.selectedCharacter.icon)
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Color(hex: playerStore.selectedCharacter.colorHex))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Lv \(playerStore.currentLevel) \(playerStore.selectedCharacter.name)")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acTextDark)

                Text(email)
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.acTextMuted)

                HStack {
                    ACBadge(
                        text: "Camp Resident",
                        textColor: Theme.Colors.acTextDark,
                        backgroundColor: Theme.Colors.acCream,
                        icon: "leaf.fill"
                    )

                    Text("\(driveStore.totalRideCount) Trips · \(Int(driveStore.totalDistanceMiles)) mi")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                .padding(.top, 2)
            }
            Spacer()
        }
        .acCardStyle()
    }
}
