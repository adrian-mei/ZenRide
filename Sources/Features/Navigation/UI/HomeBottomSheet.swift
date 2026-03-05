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
    @State private var activeSheet: BottomSheetChild?
    @State private var questBuilderPreloaded: [QuestWaypoint] = []

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

                HomeSearchBar(
                    searchQuery: $searcher.searchQuery,
                    isSearching: $searcher.isSearching,
                    isSearchFocused: $isSearchFocused,
                    onProfileTap: onProfileTap,
                    onCancelSearch: {
                        isSearchFocused = false
                        searcher.searchQuery = ""
                        searcher.searchResults = []
                        searcher.isSearching = false
                    },
                    onClearSearch: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        searcher.searchQuery = ""
                        searcher.searchResults = []
                        searcher.isSearching = false
                        isSearchFocused = true
                    },
                    onSubmitSearch: {
                        searchTask?.cancel()
                        let q = searcher.searchQuery.trimmingCharacters(in: .whitespaces)
                        guard !q.isEmpty else { return }
                        searcher.isSearching = true
                        searcher.search(for: q, near: locationProvider.currentLocation?.coordinate)
                    }
                )
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
                .padding(.horizontal)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearchFocused)

                // Mode Selector
                ModeSelector()
                    .padding(.bottom, 8)

                if !searcher.searchQuery.isEmpty {
                    HomeSearchResults(
                        isSearching: searcher.isSearching,
                        searchQuery: searcher.searchQuery,
                        searchResults: searcher.searchResults,
                        currentLocation: locationProvider.currentLocation,
                        isPlaceSaved: { name, coord in
                            savedRoutes.isPlaceSaved(name: name, coordinate: coord)
                        },
                        onRouteTo: routeTo(item:),
                        onSavePlace: { item in
                            guard let coord = item.placemark.location?.coordinate else { return }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            if savedRoutes.isPlaceSaved(name: item.name ?? "", coordinate: coord) {
                                if let savedId = savedRoutes.findExistingId(near: coord, name: item.name ?? "") {
                                    savedRoutes.togglePin(id: savedId)
                                }
                            } else {
                                savedRoutes.savePlace(name: item.name ?? "Place", coordinate: coord)
                            }
                        },
                        onAddToTripBuilder: { item in
                            guard let coord = item.placemark.location?.coordinate else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            let wp = QuestWaypoint(name: item.name ?? "Stop", coordinate: coord, icon: "mappin.circle.fill")
                            questBuilderPreloaded = [wp]
                        }
                    )
                    .padding(.horizontal)
                } else {
                    idleContent
                }
            }
        }
        .background(Theme.Colors.acCream)
        .scrollDismissesKeyboard(.interactively)
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
            HomeSheetPlayerHeader(
                level: playerStore.currentLevel,
                xp: playerStore.totalXP,
                progress: playerStore.currentLevelProgress(),
                icon: playerStore.selectedCharacter.icon,
                colorHex: playerStore.selectedCharacter.colorHex
            )
            
            HomeSheetDiscoverActions(
                onWanderTap: { activeSheet = .campCruise },
                onDiscoverNewTap: { 
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    activeSheet = .destinationSearch(nil, nil)
                }
            )

            AdventureBoardView(
                onSelect: { route in
                    let coord = CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude)
                    routeTo(item: MKMapItem(placemark: MKPlacemark(coordinate: coord)))
                },
                onAssign: { category, idx in
                    activeSheet = .destinationSearch(category, idx)
                }
            )

            QuestDashboardView()

            HomeSheetRecentMemories(memories: memoryStore.memories)

            if let car = parkedCarStore.parkedCar {
                let distanceString: String? = {
                    if let loc = locationProvider.currentLocation {
                        let dist = loc.distance(from: CLLocation(latitude: car.latitude, longitude: car.longitude)) / 1609.34
                        return String(format: "%.1f miles away", dist)
                    }
                    return nil
                }()
                HomeSheetParkedCarWidget(
                    car: car,
                    distanceString: distanceString,
                    onClear: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        parkedCarStore.unparkCar()
                    },
                    onNavigate: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        onDestinationSelected("Parked Car", car.coordinate)
                    }
                )
            }

            HomeSheetQuickActions(
                onParkVehicle: {
                    guard let loc = locationProvider.currentLocation else { return }
                    let coord = loc.coordinate
                    parkedCarStore.parkCar(at: coord, streetName: locationProvider.currentStreetName)
                },
                onMarkLocation: {
                    guard let loc = locationProvider.currentLocation else { return }
                    let coord = loc.coordinate
                    let name = "Marked \(Date().markedLocationTimestamp())"
                    savedRoutes.savePlace(name: name, coordinate: coord)
                },
                onReportIssue: {
                    if let url = URL(string: "https://github.com/anthropics/claude-code/issues") {
                        UIApplication.shared.open(url)
                    }
                }
            )
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
}
