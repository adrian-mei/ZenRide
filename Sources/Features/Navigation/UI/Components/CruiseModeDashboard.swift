import SwiftUI

struct CruiseModeDashboard: View {
    let elapsedFormatted: String
    let cruiseDistanceFormatted: String
    let cruiseDistanceUnit: String
    let currentSpeedString: String
    let activeSessionMembers: [CampCrewMember]
    
    var onSetDestination: (() -> Void)?
    var onEnd: () -> Void

    var body: some View {
        VStack(spacing: 16) {

            // Live stats: time · distance · speed
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(elapsedFormatted)
                        .font(Theme.Typography.title2)
                        .foregroundColor(.white)
                    Text("time")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                columnDivider
                VStack(spacing: 4) {
                    Text(cruiseDistanceFormatted)
                        .font(Theme.Typography.title2)
                        .foregroundColor(.white)
                    Text(cruiseDistanceUnit)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                columnDivider
                VStack(spacing: 4) {
                    Text(currentSpeedString)
                        .font(Theme.Typography.title2)
                        .foregroundColor(.white)
                    Text("mph")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)

            // Friends on the road (if multiplayer session active)
            if !activeSessionMembers.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(Theme.Typography.button)
                        .foregroundStyle(Theme.Colors.acSuccess)
                    Text("\(activeSessionMembers.count) friend\(activeSessionMembers.count == 1 ? "" : "s") on the road")
                        .font(Theme.Typography.button)
                        .foregroundStyle(Theme.Colors.acSuccess)
                    Spacer()
                    // Mini avatar pills
                    HStack(spacing: -6) {
                        ForEach(activeSessionMembers.prefix(3), id: \.id) { member in
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.acMint)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Theme.Colors.acCharcoal, lineWidth: 2))
                                Text(member.avatarURL ?? "🐾")
                                    .font(Theme.Typography.button)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.Colors.acSuccess.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Colors.acSuccess.opacity(0.3), lineWidth: 1.5)
                )
                .padding(.horizontal, 16)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { onSetDestination?() }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Find Place")
                    }
                    .font(Theme.Typography.body)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }

                Button(action: onEnd) {
                    Text("End")
                        .font(Theme.Typography.body)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Theme.Colors.acError)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.top, 16)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1, height: 44)
    }
}
