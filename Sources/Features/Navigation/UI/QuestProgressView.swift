import SwiftUI

/// Sleek horizontal timeline for Quest progress
struct QuestProgressView: View {
    @EnvironmentObject var routingService: RoutingService

    var body: some View {
        if let quest = routingService.questManager.activeQuest {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    Image(systemName: "map.fill")
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.acLeaf)

                    Text(quest.title.uppercased())
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .kerning(1.0)

                    Spacer()

                    Text("\(routingService.questManager.currentStopNumber)/\(routingService.questManager.totalStopsInQuest)")
                        .font(Theme.Typography.label)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.acWood)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 4)

                // Timeline
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 0) {
                            ForEach(0..<quest.waypoints.count, id: \.self) { idx in
                                waypointNode(idx: idx, waypoint: quest.waypoints[idx])
                                    .id(idx)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: routingService.questManager.currentLegIndex) { _, newValue in
                        withAnimation(.spring()) {
                            proxy.scrollTo(max(0, newValue), anchor: .center)
                        }
                    }
                    .onAppear {
                        proxy.scrollTo(max(0, routingService.questManager.currentLegIndex), anchor: .center)
                    }
                }
            }
            .padding(14)
            .background(Theme.Colors.acCream.opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Colors.acBorder, lineWidth: 1.5)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
            .frame(maxWidth: 340)
            .padding(.leading, 16)
        }
    }

    @ViewBuilder
    private func waypointNode(idx: Int, waypoint: QuestWaypoint) -> some View {
        let isPast = idx <= routingService.questManager.currentLegIndex
        let isTarget = idx == routingService.questManager.currentLegIndex + 1

        HStack(spacing: 0) {
            // Connector line (left)
            if idx > 0 {
                Rectangle()
                    .fill(isPast ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.5))
                    .frame(width: 20, height: 3)
            }

            // The Circle
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(isPast ? Theme.Colors.acLeaf : (isTarget ? Theme.Colors.acGold : Theme.Colors.acField))
                        .frame(width: 28, height: 28)
                        .shadow(color: isTarget ? Theme.Colors.acGold.opacity(0.4) : Color.clear, radius: 4)

                    Image(systemName: isPast ? "checkmark" : waypoint.icon)
                        .font(Theme.Typography.caption)
                        .foregroundColor(isPast || isTarget ? .white : Theme.Colors.acTextMuted)
                }
                .overlay(
                    Circle()
                        .stroke(isTarget ? Theme.Colors.acGold : Theme.Colors.acBorder, lineWidth: isTarget ? 2 : 1)
                )

                Text(waypoint.name)
                    .font(Theme.Typography.label)
                    .foregroundColor(isTarget ? Theme.Colors.acTextDark : Theme.Colors.acTextMuted)
                    .lineLimit(1)
                    .frame(width: 50)
            }
            .scaleEffect(isTarget ? 1.1 : 1.0)

            // Connector line (right)
            if idx < (routingService.questManager.activeQuest?.waypoints.count ?? 0) - 1 {
                Rectangle()
                    .fill(idx < routingService.questManager.currentLegIndex ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.5))
                    .frame(width: 20, height: 3)
            }
        }
    }
}
