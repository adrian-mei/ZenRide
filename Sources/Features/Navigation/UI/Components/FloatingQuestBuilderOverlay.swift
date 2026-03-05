import SwiftUI
import CoreLocation

struct FloatingQuestBuilderOverlay: View {
    @Binding var questWaypoints: [QuestWaypoint]
    @Binding var showQuestBuilderFloating: Bool
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService

    let onDestinationSelected: (String, CLLocationCoordinate2D) -> Void

    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                VStack(spacing: 12) {
                    HStack {
                        Text("Custom Route")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        Spacer()
                        ACBadge(text: "\(questWaypoints.count) stops", textColor: Theme.Colors.acLeaf, backgroundColor: Theme.Colors.acLeaf.opacity(0.2))
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(questWaypoints) { wp in
                                HStack(spacing: 6) {
                                    Image(systemName: wp.icon)
                                        .foregroundColor(Theme.Colors.acLeaf)
                                    Text(wp.name)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.acTextDark)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Theme.Colors.acCream)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(Theme.Colors.acBorder, lineWidth: 1))
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        ACDangerButton(title: "Clear", isFullWidth: true) {
                            withAnimation {
                                questWaypoints.removeAll()
                                showQuestBuilderFloating = false
                            }
                        }

                        Button("Start Route") {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if questWaypoints.count >= 2 {
                                let quest = DailyQuest(title: "Custom Route", waypoints: questWaypoints)
                                if let (start, end) = routingService.questManager.startQuest(quest, currentLocation: locationProvider.currentLocation?.coordinate) {
                                    Task {
                                        if let result = try? await QuestNavigationManager.generateLegRouting(from: start, to: end) {
                                            routingService.loadLeg(result: result)
                                        }
                                    }
                                }
                                let firstCoord = questWaypoints.first?.coordinate
                                    ?? locationProvider.currentLocation?.coordinate
                                    ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                                withAnimation {
                                    questWaypoints.removeAll()
                                    showQuestBuilderFloating = false
                                }
                                onDestinationSelected(quest.title, firstCoord)
                            } else {
                                if let first = questWaypoints.first {
                                    onDestinationSelected(first.name, first.coordinate)
                                    withAnimation {
                                        questWaypoints.removeAll()
                                        showQuestBuilderFloating = false
                                    }
                                }
                            }
                        }
                        .font(Theme.Typography.button)
                        .foregroundColor(.white)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                        .background(Theme.Colors.acLeaf)
                        .clipShape(Capsule())
                    }
                }
                .padding()
                .background(Theme.Colors.acCream)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                .padding(.horizontal)
                .padding(.bottom, geo.size.height * 0.15 + 20)
            }
        }
    }
}
