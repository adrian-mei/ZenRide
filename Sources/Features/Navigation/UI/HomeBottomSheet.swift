import SwiftUI
import MapKit
import CoreLocation

enum BottomSheetChild: Identifiable {
    case destinationSearch(RoutineCategory?, Int?), campCruise

    var id: String {
        switch self {
        case .destinationSearch(let category, let index):
            return "search-\(category?.rawValue ?? "none")-\(index ?? -1)"
        case .campCruise:
            return "cruise"
        }
    }
}

struct HomeBottomSheet: View {
    var onProfileTap: () -> Void
    var onDestinationSelected: (String, CLLocationCoordinate2D) -> Void
    var onCruiseTap: () -> Void
    var onRollOut: () -> Void
    var onSearchFocused: (() -> Void)?

    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var cameraStore: CameraStore
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var parkingStore: ParkingStore
    @EnvironmentObject var playerStore: PlayerStore
    @EnvironmentObject var memoryStore: MemoryStore
    @EnvironmentObject var parkedCarStore: ParkedCarStore

    @StateObject private var searcher = DestinationSearcher()
    @FocusState private var isSearchFocused: Bool
    @State private var searchTask: Task<Void, Never>?
    @State private var justSavedIndex: Int?
    @State private var nearbyParking: [ParkingSpot] = []
    @State private var activeSheet: BottomSheetChild?
    @State private var questBuilderPreloaded: [QuestWaypoint] = []
    @State private var loadingRouteId: UUID?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Drag Handle
                CenterView {
                    Capsule()
                        .fill(Theme.Colors.acBorder)
                        .frame(width: 48, height: 6)
                        .padding(.top, 12)
                }

                // Search Bar + Profile / Cancel
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .font(.system(size: 16, weight: .bold))

                        TextField("Search Destinations", text: $searcher.searchQuery)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .onChange(of: searcher.searchQuery) { _, query in
                                searchTask?.cancel()
                                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                                    searcher.searchResults = []
                                    searcher.isSearching = false
                                    return
                                }
                                searcher.isSearching = true
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 180_000_000)
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
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                searcher.searchQuery = ""
                                searcher.searchResults = []
                                searcher.isSearching = false
                                isSearchFocused = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.Colors.acTextMuted)
                                    .frame(width: 36, height: 36)
                            }
                        } else if !isSearchFocused {
                            Image(systemName: "mic.fill")
                                .foregroundColor(Theme.Colors.acTextMuted)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.acField)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))

                    if isSearchFocused {
                        Button("Cancel") {
                            isSearchFocused = false
                            searcher.searchQuery = ""
                            searcher.searchResults = []
                            searcher.isSearching = false
                        }
                        .font(Theme.Typography.button)
                        .foregroundColor(Theme.Colors.acWood)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        Button(action: onProfileTap) {
                            Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 40, height: 40)
                            .foregroundColor(Theme.Colors.acLeaf)
                            .background(Circle().fill(Theme.Colors.acCream))
                            .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 2))
                        }
                    }
                }
                .padding(.horizontal)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearchFocused)

                // Mode Selector
                ModeSelector()
                    .padding(.bottom, 8)

                // Content: search results or idle
                if !searcher.searchQuery.isEmpty {
                    searchResultsContent
                        .padding(.horizontal)
                } else {
                    idleContent
                }
            }
        }
        .background(Theme.Colors.acCream)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { refreshNearbyParking() }
        .onChange(of: isSearchFocused) { _, focused in
            if focused { onSearchFocused?() }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: searcher.searchQuery.isEmpty)
        .sheet(item: $activeSheet) { child in
            switch child {
            case .destinationSearch(let category, let index):
                DestinationSearchView(category: category, slotIndex: index) { name, coordinate in
                    onDestinationSelected(name, coordinate)
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            case .campCruise:
                CampCruiseSetupSheet(onStartCruise: onRollOut)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 24) {

            // Experience / Level Progress
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: playerStore.selectedCharacter.colorHex))
                        .frame(width: 50, height: 50)
                    Image(systemName: playerStore.selectedCharacter.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(playerStore.currentLevel)")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .contentTransition(.numericText())
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: playerStore.currentLevel)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Colors.acBorder.opacity(0.3))
                            Capsule()
                                .fill(Theme.Colors.acLeaf)
                                .frame(width: geo.size.width * playerStore.currentLevelProgress())
                                .animation(.spring(response: 0.5, dampingFraction: 0.75), value: playerStore.currentLevelProgress())
                        }
                    }
                    .frame(height: 8)
                }

                Spacer()

                Text("\(playerStore.totalXP) XP")
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Colors.acLeaf)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: playerStore.totalXP)
            }
            .padding(.horizontal)

            // Actions
            HStack(spacing: 12) {
                // Wander & Discover Button
                Button(action: { activeSheet = .campCruise }) {
                    VStack(spacing: 8) {
                        Image(systemName: "tent.fill")
                            .font(.system(size: 24, weight: .bold))
                        Text("Wander & Discover")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(ACButtonStyle(variant: .largePrimary))

                // Discover New Button (Old Search)
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    activeSheet = .destinationSearch(nil, nil)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 24, weight: .bold))
                        Text("Discover New")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(ACButtonStyle(variant: .largeSecondary))
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
            .padding(.top, 4)

            // Adventure Board (The 15 Slots + Super Intelligence)
            AdventureBoardView(
                onSelect: { route in
                    let coord = CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude)
                    routeTo(item: MKMapItem(placemark: MKPlacemark(coordinate: coord)))
                },
                onAssign: { category, idx in
                    activeSheet = .destinationSearch(category, idx)
                }
            )

            // ZenMap: Daily Quests inject here!
            QuestDashboardView()

            // Recent Memories
            if !memoryStore.memories.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recent Memories")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        Image(systemName: "eye.fill")
                            .foregroundColor(Theme.Colors.acGold)
                            .font(.caption.bold())
                        Spacer()
                    }
                    .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(memoryStore.memories.prefix(5)) { memory in
                                MemoryPolaroidCard(memory: memory)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                    }
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // Parked Car Widget
            if let car = parkedCarStore.parkedCar {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Parked Vehicle")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        Image(systemName: "parkingsign.circle.fill")
                            .foregroundColor(Theme.Colors.acSky)
                            .font(.title3)
                        Spacer()

                        Button("Clear") {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            parkedCarStore.unparkCar()
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acCoral)
                    }
                    .padding(.horizontal)

                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Theme.Colors.acSky.opacity(0.15))
                                .frame(width: 48, height: 48)
                            Image(systemName: "car.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.Colors.acSky)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            if let street = car.streetName, !street.isEmpty {
                                Text(street)
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.Colors.acTextDark)
                            } else {
                                Text("Location Saved")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                                    .foregroundColor(Theme.Colors.acTextDark)
                            }

                            if let loc = locationProvider.currentLocation {
                                let dist = loc.distance(from: CLLocation(latitude: car.latitude, longitude: car.longitude)) / 1609.34 // miles
                                Text(String(format: "%.1f miles away", dist))
                                    .font(.system(size: 13, weight: .medium, design: .rounded))
                                    .foregroundColor(Theme.Colors.acWood)
                            }
                        }
                        Spacer()

                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onDestinationSelected("Parked Car", car.coordinate)
                        } label: {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Theme.Colors.acSky)
                                .clipShape(Circle())
                        }
                    }
                    .acCardStyle(padding: 16)
                    .padding(.horizontal)
                }
                .transition(.scale.combined(with: .opacity))
            }

            // Actions
            HStack(alignment: .top, spacing: 16) {
                ACSquareActionButton(icon: "parkingsign.circle.fill", title: "Park\nVehicle", color: Theme.Colors.acSky) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    guard let loc = locationProvider.currentLocation else { return }
                    let coord = loc.coordinate
                    parkedCarStore.parkCar(at: coord, streetName: locationProvider.currentStreetName)
                }
                ACSquareActionButton(icon: "mappin.and.ellipse", title: "Mark\nLocation", color: Theme.Colors.acCoral) {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    guard let loc = locationProvider.currentLocation else { return }
                    let coord = loc.coordinate
                    let name = "Marked \(markedLocationTimestamp())"
                    savedRoutes.savePlace(name: name, coordinate: coord)
                }
                ACSquareActionButton(icon: "exclamationmark.bubble", title: "Report\nIssue", color: Theme.Colors.acGold) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    if let url = URL(string: "https://github.com/anthropics/claude-code/issues") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    @ViewBuilder
    private var searchResultsContent: some View {
        if searcher.isSearching {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(Theme.Colors.acWood)
                Text("Searching…")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.acWood)
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .transition(.opacity)
        } else if searcher.searchResults.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.Colors.acTextMuted)
                Text("No results for \"\(searcher.searchQuery)\"")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.acTextMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .transition(.opacity)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(searcher.searchResults.prefix(12).enumerated()), id: \.offset) { idx, item in
                    let userLoc = locationProvider.currentLocation
                    let distanceString: String? = {
                        guard let userLoc, let placeLoc = item.placemark.location else { return nil }
                        let miles = userLoc.distance(from: placeLoc) / 1609.34
                        return miles < 0.1 ? "Nearby" : String(format: "%.1f mi", miles)
                    }()
                    HStack(spacing: 0) {
                        SearchResultRow(
                            item: item,
                            isSaved: savedRoutes.isPlaceSaved(name: item.name ?? "", coordinate: item.placemark.coordinate),
                            distanceString: distanceString
                        ) {
                            routeTo(item: item)
                        } onSave: {
                            guard let coord = item.placemark.location?.coordinate else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if savedRoutes.isPlaceSaved(name: item.name ?? "", coordinate: coord) {
                                if let savedId = savedRoutes.findExistingId(near: coord, name: item.name ?? "") {
                                    savedRoutes.togglePin(id: savedId)
                                }
                            } else {
                                savedRoutes.savePlace(name: item.name ?? "Place", coordinate: coord)
                            }
                        }

                        // "+" pill — add to trip builder
                        Button {
                            guard let coord = item.placemark.location?.coordinate else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            let wp = QuestWaypoint(name: item.name ?? "Stop", coordinate: coord, icon: "mappin.circle.fill")
                            questBuilderPreloaded = [wp]
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(Theme.Colors.acLeaf)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 10)
                    }

                    if idx < min(searcher.searchResults.count, 12) - 1 {
                        ACSectionDivider(leadingInset: 66)
                    }
                }
            }
            .background(Theme.Colors.acField)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
            .padding(.bottom, 20)
            .transition(.opacity)
        }
    }

    private func routeTo(item: MKMapItem) {
        guard let coord = item.placemark.location?.coordinate else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let name = item.name ?? "Destination"
        savedRoutes.addRecentSearch(
            name: name,
            subtitle: item.placemark.zenFormattedAddress,
            coordinate: coord
        )
        let origin = locationProvider.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
        searcher.searchResults = []
        searcher.searchQuery = ""
        isSearchFocused = false
        onDestinationSelected(name, coord)
    }

    private func refreshNearbyParking() {
        let refLat = locationProvider.currentLocation?.coordinate.latitude ?? 37.7749
        let refLng = locationProvider.currentLocation?.coordinate.longitude ?? -122.4194
        let sorted = parkingStore.spots.sorted {
            let d0 = ($0.latitude - refLat) * ($0.latitude - refLat) + ($0.longitude - refLng) * ($0.longitude - refLng)
            let d1 = ($1.latitude - refLat) * ($1.latitude - refLat) + ($1.longitude - refLng) * ($1.longitude - refLng)
            return d0 < d1
        }
        nearbyParking = Array(sorted.prefix(5))
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }

    private func markedLocationTimestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM d, h:mm a"
        return f.string(from: Date())
    }
}
