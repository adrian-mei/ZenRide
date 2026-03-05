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
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("time")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                columnDivider
                VStack(spacing: 4) {
                    Text(cruiseDistanceFormatted)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(cruiseDistanceUnit)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                columnDivider
                VStack(spacing: 4) {
                    Text(currentSpeedString)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("mph")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)

            // Friends on the road (if multiplayer session active)
            if !activeSessionMembers.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "4CD964"))
                    Text("\(activeSessionMembers.count) friend\(activeSessionMembers.count == 1 ? "" : "s") on the road")
                        .font(Theme.Typography.button)
                        .foregroundStyle(Color(hex: "4CD964"))
                    Spacer()
                    // Mini avatar pills
                    HStack(spacing: -6) {
                        ForEach(activeSessionMembers.prefix(3), id: \.id) { member in
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.acMint)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color(hex: "1C1C1E"), lineWidth: 2))
                                Text(member.avatarURL ?? "🐾")
                                    .font(.system(size: 14))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "4CD964").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "4CD964").opacity(0.3), lineWidth: 1.5)
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
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }

                Button(action: onEnd) {
                    Text("End")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color(hex: "FF3B30"))
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
