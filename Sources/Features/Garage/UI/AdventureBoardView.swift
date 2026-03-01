import SwiftUI
import CoreLocation

struct AdventureBoardView: View {
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var playerStore: PlayerStore

    var onSelect: (SavedRoute) -> Void
    var onAssign: (RoutineCategory, Int) -> Void

    @State private var prediction: RoutineIntelligenceEngine.Prediction?
    @AppStorage("isAdventureBoardExpanded") private var isExpanded: Bool = true

    var body: some View {
        VStack(spacing: 24) {
            // Mode Indicator
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: playerStore.currentMode.icon)
                        .foregroundColor(Theme.Colors.acLeaf)
                    Text(playerStore.currentMode.displayName.uppercased())
                        .font(Theme.Typography.label)
                        .foregroundColor(Theme.Colors.acTextMuted)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(Theme.Colors.acWood)
                        .font(.system(size: 14, weight: .bold))
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                // Next Adventure Card
                if let pred = prediction {
                    Button {
                        onSelect(pred.route)
                    } label: {
                        ACDialogueBox(speakerName: "Next Adventure", speakerColor: Theme.Colors.acGold) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(pred.narrativePrompt)
                                        .font(Theme.Typography.headline)
                                        .foregroundColor(Theme.Colors.acTextDark)
                                    Text(pred.route.destinationName)
                                        .font(Theme.Typography.body)
                                        .foregroundColor(Theme.Colors.acTextMuted)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.Colors.acLeaf)
                            }
                        }
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.horizontal)
                }

                // The Grid (Filtered by Mode)
                VStack(spacing: 24) {
                    ForEach(visibleCategories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: category.icon)
                                    .foregroundColor(categoryColor(category))
                                    .font(.caption)
                                Text(category.displayName)
                                    .font(Theme.Typography.label)
                                    .foregroundColor(Theme.Colors.acTextDark.opacity(0.6))
                            }
                            .padding(.horizontal)

                            categoryRow(category: category)
                        }
                    }
                }
                .padding(.bottom, 20)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .onAppear {
            updatePrediction()
        }
        .onChange(of: playerStore.currentMode) { _, _ in
            updatePrediction()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { _ in
            updatePrediction()
        }
    }

    private var visibleCategories: [RoutineCategory] {
        switch playerStore.currentMode {
        case .standard:
            return [.home, .work, .gym, .partyMember, .holySpot]
        case .family:
            return [.home, .dayCare, .school, .afterSchool, .partyMember]
        case .newDriver:
            return [.home, .school, .work, .gym, .holySpot]
        case .motorcycle:
            return [.home, .holySpot, .partyMember] // Moto riders love their holy spots and crew
        case .singleDude:
            return [.home, .dateSpot, .gym, .partyMember, .holySpot]
        }
    }

    private func categoryColor(_ category: RoutineCategory) -> Color {
        switch category {
        case .home: return Theme.Colors.acLeaf
        case .work: return Theme.Colors.acWood
        case .gym: return Theme.Colors.acSky
        case .partyMember: return Theme.Colors.acCoral
        case .holySpot: return Theme.Colors.acGold
        case .dayCare: return Theme.Colors.acMint
        case .school: return Theme.Colors.acSky
        case .afterSchool: return Theme.Colors.acCoral
        case .dateSpot: return Theme.Colors.acCoral
        }
    }

    private func categoryRow(category: RoutineCategory) -> some View {
        HStack(spacing: 20) {
            ForEach(0..<3) { idx in
                let route = savedRoutes.routeForSlot(category: category, index: idx)
                RoutineToken(
                    category: category,
                    index: idx,
                    route: route,
                    isPredicted: prediction?.route.id == route?.id,
                    action: {
                        if let route = route {
                            onSelect(route)
                        } else {
                            onAssign(category, idx)
                        }
                    }
                )
            }
        }
        .padding(.horizontal)
    }

    private func updatePrediction() {
        withAnimation(.spring()) {
            prediction = RoutineIntelligenceEngine.predictNextAdventure(
                from: savedRoutes,
                at: locationProvider.currentLocation?.coordinate
            )
        }
    }
}
