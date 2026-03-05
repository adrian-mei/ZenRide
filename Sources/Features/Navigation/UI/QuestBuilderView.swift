import SwiftUI
import MapKit

// MARK: - Start Location

private enum StartLocation: Equatable {
    case currentLocation
    case custom(QuestWaypoint)

    var displayName: String {
        switch self {
        case .currentLocation: return "Current Location"
        case .custom(let wp): return wp.name
        }
    }
}

// MARK: - QuestBuilderView

struct QuestBuilderView: View {
    @EnvironmentObject var questStore: QuestStore
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var savedRoutes: SavedRoutesStore

    @Environment(\.dismiss) private var dismiss

    var preloadedWaypoints: [QuestWaypoint] = []
    var preloadedTitle: String = ""
    var onStartTrip: ((String, CLLocationCoordinate2D) -> Void)?

    @State private var questName = "My Cozy Commute"
    @State private var waypoints: [QuestWaypoint] = []
    @State private var startLocation: StartLocation = .currentLocation

    @State private var showAddStop = false
    @State private var showChooseStart = false
    @State private var addStopMode: AddStopMode = .stop

    private enum AddStopMode { case stop, start }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationTitle("Plan a Trip")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                            .foregroundColor(Theme.Colors.acWood)
                    }
                }
        }
        .sheet(isPresented: $showAddStop) {
            AddStopSheet { waypoint in
                if addStopMode == .start {
                    startLocation = .custom(waypoint)
                } else {
                    waypoints.append(waypoint)
                }
            }
        }
        .onAppear {
            if waypoints.isEmpty && !preloadedWaypoints.isEmpty {
                waypoints = preloadedWaypoints
            }
            if !preloadedTitle.isEmpty && questName == "My Cozy Commute" {
                questName = preloadedTitle
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Theme.Colors.acField.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    nameCard
                    startLocationCard
                    stopsCard
                    startTripButton
                }
                .padding()
            }
        }
    }

    @ViewBuilder
    private var nameCard: some View {
        ACTextField(title: "Quest Name", placeholder: "e.g. Morning Run", text: $questName)
            .acCardStyle(padding: 20)
    }

    @ViewBuilder
    private var startLocationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            ACSectionHeader(title: "STARTING FROM", icon: "location.circle.fill", color: Theme.Colors.acSky)
            HStack(spacing: 10) {
                Button { startLocation = .currentLocation } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "location.fill").font(.system(size: 13, weight: .semibold))
                        Text("📍 Current Location").font(Theme.Typography.button)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(startLocation == .currentLocation ? Theme.Colors.acSky : Theme.Colors.acCream)
                    .foregroundColor(startLocation == .currentLocation ? .white : Theme.Colors.acTextDark)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(startLocation == .currentLocation ? Theme.Colors.acSky : Theme.Colors.acBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)

                Button { addStopMode = .start; showAddStop = true } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass").font(.system(size: 13, weight: .semibold))
                        Text(startLocationCustomLabel)
                            .font(Theme.Typography.button)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(isCustomStart ? Theme.Colors.acWood : Theme.Colors.acCream)
                    .foregroundColor(isCustomStart ? .white : Theme.Colors.acTextDark)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(isCustomStart ? Theme.Colors.acWood : Theme.Colors.acBorder, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
        }
        .acCardStyle(padding: 20)
    }

    @ViewBuilder
    private var stopsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            ACSectionHeader(title: "YOUR STOPS", icon: "map.fill")
            if waypoints.isEmpty {
                Text("Add stops to build your route.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, wp in
                    waypointRow(index: index, wp: wp)
                }
            }
            Button { addStopMode = .stop; showAddStop = true } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill").font(.system(size: 18))
                    Text("Add a Stop").font(Theme.Typography.button)
                }
            }
            .buttonStyle(ACButtonStyle(variant: .secondary))
        }
        .acCardStyle(padding: 20)
    }

    @ViewBuilder
    private func waypointRow(index: Int, wp: QuestWaypoint) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "\(index + 1).circle.fill")
                .foregroundColor(Theme.Colors.acLeaf)
                .font(.system(size: 20))
            Image(systemName: wp.icon).foregroundColor(Theme.Colors.acTextDark)
            Text(wp.name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextDark)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = waypoints.remove(at: index)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.Colors.acCoral)
                    .frame(width: 36, height: 36)
                    .background(Theme.Colors.acCoral.opacity(0.12))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Theme.Colors.acCream)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.acBorder, lineWidth: 1))
    }

    @ViewBuilder
    private var startTripButton: some View {
        Button { startTrip() } label: {
            HStack(spacing: 8) {
                Image(systemName: "flag.checkered").font(.system(size: 18))
                Text("Start Trip").font(Theme.Typography.button)
            }
        }
        .buttonStyle(ACButtonStyle(variant: .primary))
        .disabled(waypoints.isEmpty)
        .opacity(waypoints.isEmpty ? 0.5 : 1)
        .padding(.bottom, 20)
    }

    // MARK: - Helpers

    private var isCustomStart: Bool {
        if case .custom = startLocation { return true }
        return false
    }

    private var startLocationCustomLabel: String {
        if case .custom(let wp) = startLocation { return wp.name }
        return "🔍 Choose a Start"
    }

    private func startTrip() {
        var allWaypoints = waypoints
        var startCoord: CLLocationCoordinate2D?

        switch startLocation {
        case .currentLocation:
            startCoord = locationProvider.currentLocation?.coordinate
        case .custom(let wp):
            allWaypoints.insert(wp, at: 0)
            startCoord = wp.coordinate
        }

        let quest = DailyQuest(title: questName, waypoints: allWaypoints)
        questStore.addQuest(quest)
                if let (start, end) = routingService.questManager.startQuest(quest, currentLocation: startCoord) {
            Task {
                if let result = try? await QuestNavigationManager.generateLegRouting(from: start, to: end) {
                    routingService.loadLeg(result: result)
                }
            }
        }

        let firstStopName = allWaypoints.first?.name ?? questName
        let firstStopCoord = allWaypoints.first?.coordinate
            ?? startCoord
            ?? Constants.sfCenter

        dismiss()
        onStartTrip?(firstStopName, firstStopCoord)
    }
}

// MARK: - AddStopSheet

