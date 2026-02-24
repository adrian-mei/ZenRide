import SwiftUI
import MapKit

// MARK: - Searcher

class DestinationSearcher: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false

    private var activeSearch: MKLocalSearch?

    func search(for query: String, near location: CLLocationCoordinate2D? = nil) {
        activeSearch?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []; isSearching = false; return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let center = location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        activeSearch = MKLocalSearch(request: request)
        activeSearch?.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                guard let response = response, error == nil else {
                    Log.error("Search", "MKLocalSearch failed: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                self?.searchResults = response.mapItems
            }
        }
    }
}

// MARK: - Main View

struct DestinationSearchView: View {
    @ObservedObject var searcher: DestinationSearcher
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var cameraStore: CameraStore
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var journal: RideJournal
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var driveStore: DriveStore
    @EnvironmentObject var parkingStore: ParkingStore

    @Binding var routeState: RouteState
    @Binding var destinationName: String
    var onSearchFocused: (() -> Void)? = nil

    @FocusState private var isSearchFocused: Bool
    @State private var searchTask: Task<Void, Never>?
    @State private var justSavedIndex: Int? = nil
    @State private var cachedSuggestions: [SavedRoute] = []
    @State private var nearbyParking: [ParkingSpot] = []

    var body: some View {
        ZStack(alignment: .top) {
            // Scrollable content underneath
            VStack(spacing: 0) {
                // Invisible spacer to push content below the search bar
                Color.clear.frame(height: 90)
                
                if searcher.searchQuery.isEmpty {
                    idleList
                } else {
                    searchResults
                }
            }
            
            // Floating, frosted search bar on top
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    searchBar
                        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearchFocused)
                    
                    if isSearchFocused {
                        Button("Cancel") {
                            isSearchFocused = false
                            searcher.searchQuery = ""
                            searcher.searchResults = []
                            searcher.isSearching = false
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                        .padding(.leading, 12)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.top, 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                
                Divider().opacity(0.3)
            }
            .background(.regularMaterial) // This creates the dynamic frost effect
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: searcher.searchQuery.isEmpty)
        .onChange(of: isSearchFocused) { if $0 { onSearchFocused?() } }
        .onAppear {
            refreshSuggestions()
            refreshNearbyParking()
        }
        .task {
            try? await Task.sleep(nanoseconds: 150_000_000) // 150ms — let sheet settle
            isSearchFocused = true
        }
        .onChange(of: savedRoutes.routes.count) { _ in refreshSuggestions() }
        .onReceive(NotificationCenter.default.publisher(for: .zenRideNavigateTo)) { note in
            if let route = note.object as? SavedRoute { navigate(to: route) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .zenRideParkingRoute)) { note in
            guard let lat = note.userInfo?["lat"] as? Double,
                  let lng = note.userInfo?["lng"] as? Double,
                  let name = note.userInfo?["name"] as? String else { return }
            routeToParking(coordinate: CLLocationCoordinate2D(latitude: lat, longitude: lng), name: name)
        }
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .medium))

            TextField("Search destination", text: $searcher.searchQuery)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .font(.system(size: 17))
                .onChange(of: searcher.searchQuery) { query in
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

            if searcher.searchQuery.isEmpty && !isSearchFocused {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.secondary)
                    .frame(width: 36, height: 36)
            } else {
                if !searcher.searchQuery.isEmpty {
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        searcher.searchQuery = ""
                        searcher.searchResults = []
                        searcher.isSearching = false
                        // Keep focus — user wants to type something new
                        isSearchFocused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                            .frame(width: 36, height: 36)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: - Idle: List with native swipe actions

    private var idleList: some View {
        List {
            // Category chips — inlined as a full-width list row
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        chip("house.fill",      "Home",     .cyan)    { searcher.searchQuery = "Home" }
                        chip("briefcase.fill",  "Work",     .cyan)    { searcher.searchQuery = "Work" }
                        chip("fuelpump.fill",   "Gas",      .orange)  { searcher.searchQuery = "Gas Stations" }
                        chip("wrench.and.screwdriver.fill", "Shop", .gray) { searcher.searchQuery = "Motorcycle Repair" }
                        chip("cup.and.saucer.fill", "Coffee", .orange) { searcher.searchQuery = "Coffee" }
                        chip("cross.fill",      "Hospital", .red)     { searcher.searchQuery = "Hospital" }
                        // Parking chip — shows nearby parking section in the idle list
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            searcher.searchQuery = ""
                            searcher.searchResults = []
                            isSearchFocused = false
                            refreshNearbyParking()
                            onSearchFocused?()
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    Circle().fill(Color.purple).frame(width: 50, height: 50)
                                    Image(systemName: "parkingsign").font(.system(size: 20)).foregroundStyle(.white)
                                }
                                Text("Parking").font(.caption).fontWeight(.medium).foregroundStyle(.primary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            // Nearby Parking
            if !nearbyParking.isEmpty {
                Section {
                    ForEach(nearbyParking) { spot in
                        let meterLabel = spot.isMetered ? "Metered" : "Unmetered"
                        let spacesText = spot.spacesCount > 1 ? "\(spot.spacesCount) spaces" : "1 space"
                        let subtitle = spot.neighborhood.map { "\(spacesText) · \(meterLabel) · \($0)" } ?? "\(spacesText) · \(meterLabel)"
                        SavedRouteRow(
                            systemIcon: "parkingsign",
                            iconColor: .purple,
                            title: spot.street.capitalized,
                            subtitle: subtitle
                        ) {
                            routeToParking(
                                coordinate: CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude),
                                name: spot.street
                            )
                        }
                    }
                } header: { listHeader("Nearby Parking", "parkingsign", .purple) }
            }

            // Smart suggestions
            if !cachedSuggestions.isEmpty {
                Section {
                    ForEach(cachedSuggestions) { route in
                        SavedRouteRow(
                            systemIcon: "sparkles", iconColor: .yellow,
                            title: route.destinationName,
                            subtitle: typicalTimeLabel(route)
                        ) { navigate(to: route) }
                    }
                } header: { listHeader("Suggested", "sparkles", .yellow) }
            }

            // Bookmarked Routes
            let bookmarked = driveStore.bookmarkedRecords
            if !bookmarked.isEmpty {
                Section {
                    ForEach(bookmarked) { record in
                        SavedRouteRow(
                            systemIcon: "bookmark.fill", iconColor: .cyan,
                            title: record.destinationName,
                            subtitle: relativeDate(record.lastDrivenDate)
                        ) {
                            let coord = record.destinationCoordinate
                            let origin = locationProvider.currentLocation?.coordinate
                                ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                            destinationName = record.destinationName
                            Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
                            isSearchFocused = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { routeState = .reviewing }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                withAnimation { driveStore.toggleBookmark(id: record.id) }
                            } label: { Label("Remove", systemImage: "bookmark.slash") }
                                .tint(.gray)
                        }
                    }
                } header: { listHeader("Bookmarked Routes", "bookmark.fill", .cyan) }
            }

            // Saved Places
            let pinned = savedRoutes.pinnedRoutes
            Section {
                if pinned.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "star")
                            .foregroundStyle(.secondary)
                            .frame(width: 20)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No saved places yet")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text("Tap \(Image(systemName: "bookmark")) on any search result")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(pinned) { route in
                        SavedRouteRow(
                            systemIcon: "star.fill", iconColor: .orange,
                            title: route.destinationName,
                            subtitle: route.useCount > 0 ? relativeDate(route.lastUsedDate) : "Saved place"
                        ) { navigate(to: route) }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation { savedRoutes.deleteRoute(id: route.id) }
                            } label: { Label("Delete", systemImage: "trash") }

                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation { savedRoutes.togglePin(id: route.id) }
                            } label: { Label("Unsave", systemImage: "star.slash") }
                                .tint(.gray)
                        }
                    }
                }
            } header: { listHeader("Saved Places", "star.fill", .orange) }

            // Recent
            let recent = savedRoutes.topRecent(limit: 8).filter { !$0.isPinned }
            if !recent.isEmpty {
                Section {
                    ForEach(recent) { route in
                        SavedRouteRow(
                            systemIcon: "clock.arrow.circlepath", iconColor: .secondary,
                            title: route.destinationName,
                            subtitle: relativeDate(route.lastUsedDate)
                        ) { navigate(to: route) }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation { savedRoutes.togglePin(id: route.id) }
                            } label: { Label("Save", systemImage: "star.fill") }
                                .tint(.orange)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation { savedRoutes.deleteRoute(id: route.id) }
                            } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                } header: { listHeader("Recent", "clock", .secondary) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .transition(.opacity)
    }

    // MARK: - Search Results

    private var searchResults: some View {
        Group {
            if searcher.isSearching {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.4)
                        .tint(.cyan)
                    Text("Searching…")
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.cyan.opacity(0.8))
                        .kerning(0.5)
                    Spacer()
                }
                .transition(.opacity)
            } else if searcher.searchResults.isEmpty && !searcher.searchQuery.isEmpty {
                VStack(spacing: 10) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 32))
                        .foregroundStyle(.tertiary)
                    Text("No results for \"\(searcher.searchQuery)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, 32)
                .transition(.opacity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searcher.searchResults.prefix(12).enumerated()), id: \.offset) { idx, item in
                            let userLoc = locationProvider.currentLocation
                            let distanceString: String? = {
                                guard let userLoc, let placeLoc = item.placemark.location else { return nil }
                                let miles = userLoc.distance(from: placeLoc) / 1609.34
                                return miles < 0.1 ? "Nearby" : String(format: "%.1f mi", miles)
                            }()
                            SearchResultRow(
                                item: item,
                                isSaved: justSavedIndex == idx,
                                distanceString: distanceString
                            ) {
                                routeTo(item: item)
                            } onSave: {
                                guard let coord = item.placemark.location?.coordinate else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                savedRoutes.savePlace(name: item.name ?? "Place", coordinate: coord)
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    justSavedIndex = idx
                                }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                    withAnimation { justSavedIndex = nil }
                                }
                            }

                            if idx < min(searcher.searchResults.count, 12) - 1 {
                                Divider().padding(.leading, 66)
                            }
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 10)
                    .padding(.bottom, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: searcher.isSearching)
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: searcher.searchResults.count)
    }

    // MARK: - Helpers

    @ViewBuilder
    private func chip(_ icon: String, _ title: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
            isSearchFocused = true   // keep keyboard up
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle().fill(color).frame(width: 50, height: 50)
                    Image(systemName: icon).font(.system(size: 20)).foregroundStyle(.white)
                }
                Text(title).font(.caption).fontWeight(.medium).foregroundStyle(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func listHeader(_ title: String, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(color)
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func routeToParking(coordinate: CLLocationCoordinate2D, name: String) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let origin = locationProvider.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        destinationName = "\(name) Parking"
        Task { await routingService.calculateSafeRoute(from: origin, to: coordinate, avoiding: cameraStore.cameras) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { routeState = .reviewing }
    }

    private func navigate(to route: SavedRoute) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let coord = CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude)
        let origin = locationProvider.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        destinationName = route.destinationName
        Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            routeState = .reviewing
        }
    }

    private func routeTo(item: MKMapItem) {
        guard let coord = item.placemark.location?.coordinate else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let origin = locationProvider.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        destinationName = item.name ?? "Destination"
        Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
        searcher.searchResults = []
        searcher.searchQuery = ""
        isSearchFocused = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            routeState = .reviewing
        }
    }

    private func refreshNearbyParking() {
        let refLat = locationProvider.currentLocation?.coordinate.latitude ?? 37.7749
        let refLng = locationProvider.currentLocation?.coordinate.longitude ?? -122.4194
        // Use squared delta (no sqrt needed) for fast approximate distance sort
        let sorted = parkingStore.spots.sorted {
            let d0 = ($0.latitude - refLat) * ($0.latitude - refLat) + ($0.longitude - refLng) * ($0.longitude - refLng)
            let d1 = ($1.latitude - refLat) * ($1.latitude - refLat) + ($1.longitude - refLng) * ($1.longitude - refLng)
            return d0 < d1
        }
        nearbyParking = Array(sorted.prefix(5))
    }

    private func refreshSuggestions() {
        let hour = Calendar.current.component(.hour, from: Date())
        cachedSuggestions = hour >= 5 ? savedRoutes.suggestions(for: hour) : []
    }

    private func typicalTimeLabel(_ route: SavedRoute) -> String {
        let hours = route.typicalDepartureHours.sorted()
        guard let h = hours.dropFirst(hours.count / 4).first else { return "Frequently visited" }
        let period = h < 12 ? "am" : "pm"
        let display = h == 0 ? 12 : (h > 12 ? h - 12 : h)
        return "Usually around \(display)\(period)"
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }
}

// MARK: - RouteListRow (used in List — gets native separators + swipe)

private struct SavedRouteRow: View {
    let systemIcon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.13))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemIcon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(Color.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SearchResultRow

private struct SearchResultRow: View {
    let item: MKMapItem
    let isSaved: Bool
    let distanceString: String?
    let action: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Main tap target — navigate
            Button(action: action) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 42, height: 42)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.blue)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Unknown")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(formatAddress(placemark: item.placemark))
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(1)
                            if let dist = distanceString {
                                Text(dist)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color.cyan)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Color.cyan.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Bookmark save button — shows animated checkmark when saved
            Button(action: onSave) {
                ZStack {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.blue)
                        .scaleEffect(isSaved ? 1 : 0.01)
                        .opacity(isSaved ? 1 : 0)

                    Image(systemName: "bookmark")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.secondary)
                        .scaleEffect(isSaved ? 0.01 : 1)
                        .opacity(isSaved ? 0 : 1)
                }
                .frame(width: 50, height: 50)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSaved)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
    
    private func formatAddress(placemark: MKPlacemark) -> String {
        // Build detailed street address (e.g. "123 Main St, San Francisco")
        var components: [String] = []
        
        var street = ""
        if let subThoroughfare = placemark.subThoroughfare {
            street += subThoroughfare + " "
        }
        if let thoroughfare = placemark.thoroughfare {
            street += thoroughfare
        }
        
        if !street.isEmpty {
            components.append(street)
        }
        
        if let city = placemark.locality {
            components.append(city)
        } else if let area = placemark.administrativeArea {
            components.append(area)
        }
        
        return components.isEmpty ? "Unknown Address" : components.joined(separator: ", ")
    }
}

// MARK: - Legacy type aliases for GarageView compatibility

struct CategoryChip: View {
    let icon: String
    let title: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color).frame(width: 52, height: 52)
                    Image(systemName: icon).font(.title3).foregroundStyle(.white)
                }
                Text(title).font(.caption).fontWeight(.medium).foregroundStyle(.primary)
            }
        }
    }
}

typealias CategoryButton = CategoryChip

struct FavoriteRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(color.opacity(0.15)).frame(width: 40, height: 40)
                Image(systemName: icon).font(.system(size: 20)).foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body).foregroundStyle(color == .gray ? Color.blue : Color.primary)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.subheadline).foregroundStyle(Color.secondary)
                }
            }
            Spacer()
        }
        .padding(.vertical, 12).padding(.horizontal, 16)
    }
}
