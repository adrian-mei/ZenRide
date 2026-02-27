import SwiftUI

/// Overlay shown during navigation to track Quest progress
struct QuestProgressView: View {
    @EnvironmentObject var routingService: RoutingService
    
    var body: some View {
        if let quest = routingService.activeQuest {
            VStack(spacing: 8) {
                Text(quest.title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                
                HStack(spacing: 4) {
                    ForEach(0..<quest.waypoints.count, id: \.self) { idx in
                        let wp = quest.waypoints[idx]
                        let isPast = idx < routingService.currentLegIndex
                        let isCurrent = idx == routingService.currentLegIndex
                        
                        VStack {
                            ZStack {
                                Circle()
                                    .fill(isPast ? Theme.Colors.acLeaf : (isCurrent ? Theme.Colors.acGold : Theme.Colors.acBorder.opacity(0.3)))
                                    .frame(width: 32, height: 32)
                                
                                Image(systemName: wp.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(isPast || isCurrent ? .white : Theme.Colors.acTextMuted)
                            }
                            
                            Text(wp.name)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundColor(isCurrent ? Theme.Colors.acTextDark : Theme.Colors.acTextMuted)
                                .lineLimit(1)
                        }
                        .frame(width: 60)
                        
                        if idx < quest.waypoints.count - 1 {
                            Rectangle()
                                .fill(isPast ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.3))
                                .frame(height: 4)
                        }
                    }
                }
            }
            .acCardStyle(padding: 16)
            .padding(.horizontal)
            .padding(.top, 50) // push down from dynamic island
        }
    }
}
