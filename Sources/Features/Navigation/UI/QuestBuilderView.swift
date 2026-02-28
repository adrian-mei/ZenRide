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
    var onStartTrip: ((String, CLLocationCoordinate2D) -> Void)? = nil

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
                        Text(startLocationCustomLabel).font(Theme.Typography.button).lineLimit(1)
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
                .lineLimit(1)
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
        routingService.startQuest(quest, currentLocation: startCoord)

        let firstStopName = allWaypoints.first?.name ?? questName
        let firstStopCoord = allWaypoints.first?.coordinate
            ?? startCoord
            ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        dismiss()
        onStartTrip?(firstStopName, firstStopCoord)
    }
}

// MARK: - AddStopSheet

private struct AddStopSheet: View {
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var savedRoutes: SavedRoutesStore

    @Environment(\.dismiss) private var dismiss

    let onSelect: (QuestWaypoint) -> Void

    @StateObject private var searcher = DestinationSearcher()
    @FocusState private var isSearchFocused: Bool
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .font(.system(size: 16, weight: .bold))

                        TextField("Search for a place…", text: $searcher.searchQuery)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .onChange(of: searcher.searchQuery) { _, query in
                                searchTask?.cancel()
                                guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
                                    searcher.searchResults = []
                                    searcher.isSearching = false
                                    return
                                }
                                searcher.isSearching = true
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 200_000_000)
                                    guard !Task.isCancelled else { return }
                                    searcher.search(for: query, near: locationProvider.currentLocation?.coordinate)
                                }
                            }
                            .onSubmit {
                                searchTask?.cancel()
                                let q = searcher.searchQuery.trimmingCharacters(in: .whitespaces)
                                guard !q.isEmpty else { return }
                                searcher.isSearching = true
                                searcher.search(for: q, near: locationProvider.currentLocation?.coordinate)
                            }

                        if !searcher.searchQuery.isEmpty {
                            Button {
                                searcher.searchQuery = ""
                                searcher.searchResults = []
                                searcher.isSearching = false
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.Colors.acTextMuted)
                                    .frame(width: 36, height: 36)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.acCream)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
                    .padding()

                    // Results
                    if searcher.isSearching {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView().scaleEffect(1.4).tint(Theme.Colors.acWood)
                            Text("Searching…")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.acWood)
                        }
                        Spacer()
                    } else if searcher.searchResults.isEmpty && !searcher.searchQuery.isEmpty {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundStyle(Theme.Colors.acTextMuted)
                            Text("No results for \"\(searcher.searchQuery)\"")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.acTextMuted)
                                .multilineTextAlignment(.center)
                        }
                        Spacer()
                    } else if !searcher.searchResults.isEmpty {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(Array(searcher.searchResults.prefix(12).enumerated()), id: \.offset) { idx, item in
                                    let userLoc = locationProvider.currentLocation
                                    let distanceString: String? = {
                                        guard let userLoc, let placeLoc = item.placemark.location else { return nil }
                                        let miles = userLoc.distance(from: placeLoc) / 1609.34
                                        return miles < 0.1 ? "Nearby" : String(format: "%.1f mi", miles)
                                    }()
                                    SearchResultRow(
                                        item: item,
                                        isSaved: false,
                                        distanceString: distanceString
                                    ) {
                                        guard let coord = item.placemark.location?.coordinate else { return }
                                        let wp = QuestWaypoint(
                                            name: item.name ?? "Stop",
                                            coordinate: coord,
                                            icon: iconFor(item)
                                        )
                                        onSelect(wp)
                                        dismiss()
                                    } onSave: {
                                        guard let coord = item.placemark.location?.coordinate else { return }
                                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                        savedRoutes.savePlace(name: item.name ?? "Place", coordinate: coord)
                                    }

                                    if idx < min(searcher.searchResults.count, 12) - 1 {
                                        ACSectionDivider(leadingInset: 66)
                                    }
                                }
                            }
                            .background(Theme.Colors.acCream)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
                            .padding(.horizontal)
                        }
                    } else {
                        let pinned = savedRoutes.pinnedRoutes
                        let recents = savedRoutes.recentSearches
                        
                        if pinned.isEmpty && recents.isEmpty {
                            Spacer()
                            Image(systemName: "mappin.and.ellipse")
                                .font(.system(size: 48))
                                .foregroundStyle(Theme.Colors.acBorder)
                            Text("Search for a destination")
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.acTextMuted)
                                .padding(.top, 8)
                            Spacer()
                        } else {
                            List {
                                if !pinned.isEmpty {
                                    Section("Bookmarked") {
                                        ForEach(pinned) { route in
                                            SavedRouteRow(systemIcon: "bookmark.fill", iconColor: Theme.Colors.acCoral, title: route.destinationName, subtitle: "Saved Place") {
                                                let wp = QuestWaypoint(name: route.destinationName, coordinate: CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude), icon: "bookmark.fill")
                                                onSelect(wp)
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                                
                                if !recents.isEmpty {
                                    Section("Recent Searches") {
                                        ForEach(recents) { recent in
                                            SavedRouteRow(systemIcon: "clock.fill", iconColor: Theme.Colors.acTextMuted, title: recent.name, subtitle: recent.subtitle) {
                                                let wp = QuestWaypoint(name: recent.name, coordinate: CLLocationCoordinate2D(latitude: recent.latitude, longitude: recent.longitude), icon: "clock.fill")
                                                onSelect(wp)
                                                dismiss()
                                            }
                                        }
                                    }
                                }
                            }
                            .listStyle(.plain)
                            .scrollContentBackground(.hidden)
                        }
                    }
                }
            }
            .navigationTitle("Add a Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
            .onAppear { isSearchFocused = true }
        }
    }

    private func iconFor(_ item: MKMapItem) -> String {
        let category = item.pointOfInterestCategory
        switch category {
        case .cafe, .restaurant, .bakery, .brewery, .foodMarket, .winery: return "cup.and.saucer.fill"
        case .gasStation: return "fuelpump.fill"
        case .parking: return "parkingsign.circle.fill"
        case .hospital, .pharmacy: return "cross.case.fill"
        case .hotel, .campground: return "tent.fill"
        case .store: return "cart.fill"
        case .school, .university, .library: return "books.vertical.fill"
        case .airport, .publicTransport: return "airplane"
        default: return "mappin.circle.fill"
        }
    }
}
