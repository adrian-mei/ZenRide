import SwiftUI

struct PostRideToast: View {
    let info: PostRideInfo

    var body: some View {
        ACDialogueBox(speakerName: "Trip Summary", speakerColor: Theme.Colors.acLeaf) {
            VStack(alignment: .leading, spacing: 12) {
                Text("What an adventure!")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)

                HStack(spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("DISTANCE")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.acTextMuted)
                        Text(String(format: "%.1f mi", info.distanceMiles))
                            .font(Theme.Typography.body)
                            .bold()
                    }

                    VStack(alignment: .leading) {
                        Text("EXPERIENCE")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.acTextMuted)
                        Text("+\(info.xpEarned) XP")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acLeaf)
                            .bold()
                    }

                    if info.zenScore > 0 {
                        VStack(alignment: .leading) {
                            Text("ZEN")
                                .font(Theme.Typography.label)
                                .foregroundColor(Theme.Colors.acTextMuted)
                            Text("\(info.zenScore)")
                                .font(Theme.Typography.body)
                                .bold()
                        }
                    }
                }

                if info.moneySaved > 0 {
                    Text("Saved $\(Int(info.moneySaved)) by being mindful!")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }
}

struct LevelUpToast: View {
    let level: Int
    let characters: [Character]
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.acGold.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "star.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.acGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LEVEL UP!")
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Colors.acGold)
                    .kerning(1)
                Text("You reached Level \(level)")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)

                if !characters.isEmpty {
                    Text("Unlocked \(characters.map { $0.name }.joined(separator: ", "))!")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .acGlass(cornerRadius: 16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acGold, lineWidth: 2))
        .shadow(color: Theme.Colors.acGold.opacity(0.4), radius: 0, x: 0, y: 5)
        .padding(.horizontal, 16)
    }
}
