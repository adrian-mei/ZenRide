import SwiftUI

struct CampCrewStatsSheet: View {
    @EnvironmentObject var multiplayerService: MultiplayerService
    @Environment(\.dismiss) private var dismiss
    @State private var showInvite = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()

                if let session = multiplayerService.activeSession {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Header
                            VStack(spacing: 8) {
                                Text("Destination")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.Colors.acWood)
                                    .kerning(1.2)
                                Text(session.destinationName)
                                    .font(Theme.Typography.title)
                                    .foregroundColor(Theme.Colors.acTextDark)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, 24)

                            // Multi-stop route (if any)
                            if !session.waypoints.isEmpty {
                                sharedRouteCard(session.waypoints, isOffline: session.isOfflineSaved)
                            }

                            // Invite / Share
                            inviteRow

                            // Members List
                            VStack(spacing: 16) {
                                CrewMemberRow(
                                    name: "You",
                                    emoji: "🦊",
                                    speedMph: 45.0,
                                    etaSeconds: 600,
                                    distanceMeters: 8000,
                                    isHost: session.isHost
                                )
                                ForEach(session.members) { member in
                                    CrewMemberRow(
                                        name: member.name,
                                        emoji: member.avatarURL ?? "🐶",
                                        speedMph: member.speedMph,
                                        etaSeconds: member.etaSeconds,
                                        distanceMeters: member.distanceToDestinationMeters,
                                        isHost: false
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 40)
                    }
                } else {
                    Text("No active session.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
            }
            .navigationTitle("Camp Crew")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
        .sheet(isPresented: $showInvite) {
            InviteCrewSheet()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func sharedRouteCard(_ waypoints: [QuestWaypoint], isOffline: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "map.fill")
                    .foregroundColor(Theme.Colors.acLeaf)
                Text("SHARED ROUTE")
                    .font(.system(size: 12, weight: .black, design: .rounded))
                    .foregroundColor(Theme.Colors.acLeaf)
                    .kerning(1.5)
                Spacer()
                if isOffline {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12))
                        Text("Offline")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(Theme.Colors.acSky)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.acSky.opacity(0.15))
                    .clipShape(Capsule())
                }
            }

            ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, wp in
                HStack(spacing: 10) {
                    Image(systemName: "\(index + 1).circle.fill")
                        .foregroundColor(Theme.Colors.acLeaf)
                        .font(.system(size: 16))
                    Image(systemName: wp.icon)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .font(.system(size: 14))
                    Text(wp.name)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .lineLimit(1)
                }
            }
        }
        .acCardStyle(padding: 16)
        .padding(.horizontal)
    }

    @ViewBuilder
    private var inviteRow: some View {
        Button {
            showInvite = true
        } label: {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.Colors.acWood.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(Theme.Colors.acWood)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Invite Friends")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                    if let code = multiplayerService.inviteCode {
                        Text("Code: \(code)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.Colors.acLeaf)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Colors.acBorder)
            }
            .padding(14)
            .background(Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .padding(.horizontal)
    }
}

private struct CrewMemberRow: View {
    let name: String
    let emoji: String
    let speedMph: Double
    let etaSeconds: Int?
    let distanceMeters: Int?
    let isHost: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.acCream)
                    .frame(width: 50, height: 50)
                    .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 2))
                
                Text(emoji)
                    .font(.system(size: 28))
                
                if isHost {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.Colors.acGold)
                        .offset(x: 16, y: -16)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "speedometer")
                        Text(String(format: "%.0f mph", speedMph))
                    }
                    
                    if let eta = etaSeconds {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text(formatDuration(eta))
                        }
                    }
                }
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
            }
            
            Spacer()
            
            if let dist = distanceMeters {
                let miles = Double(dist) * 0.000621371
                Text(String(format: "%.1f mi", miles))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.acWood)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.Colors.acWood.opacity(0.15))
                    .clipShape(Capsule())
            }
        }
        .acCardStyle(padding: 16)
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let r = m % 60
        return "\(h)h \(r)m"
    }
}
