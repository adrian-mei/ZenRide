import SwiftUI

struct CampCrewView: View {
    @EnvironmentObject var multiplayerService: MultiplayerService
    @State private var showStatsSheet = false
    
    var body: some View {
        Button(action: {
            showStatsSheet = true
        }) {
            VStack(alignment: .leading, spacing: 6) {
                Text("ROAD TRIP CREW")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextDark.opacity(0.6))
                    .padding(.leading, 4)
                
                if let session = multiplayerService.activeSession {
                    HStack(spacing: -8) {
                        // Local user (host/self)
                        crewAvatar("🦊", zIndex: Double(session.members.count + 1))
                        
                        // Connected friends
                        ForEach(Array(session.members.enumerated()), id: \.element.id) { index, member in
                            crewAvatar(member.avatarURL ?? "🐶", zIndex: Double(session.members.count - index))
                        }
                        
                        // Small plus indicator
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.acField)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Circle()
                                        .stroke(Theme.Colors.acBorder, style: StrokeStyle(lineWidth: 2, dash: [4]))
                                )
                            
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.Colors.acTextMuted)
                        }
                        .padding(.leading, 12)
                    }
                } else {
                    Text("No active session")
                        .font(Theme.Typography.body)
                }
            }
            .padding(12)
            .background(Theme.Colors.acCream.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Theme.Colors.acBorder.opacity(0.5), lineWidth: 2)
            )
            .shadow(color: Theme.Colors.acBorder.opacity(0.3), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showStatsSheet) {
            CampCrewStatsSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private func crewAvatar(_ emoji: String, zIndex: Double) -> some View {
        ZStack {
            Circle()
                .fill(Theme.Colors.acCream)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle()
                        .stroke(Theme.Colors.acBorder, lineWidth: 2)
                )
            
            Text(emoji)
                .font(.system(size: 20))
        }
        .shadow(color: Theme.Colors.acBorder.opacity(0.3), radius: 2, x: 0, y: 2)
        .zIndex(zIndex)
    }
}
