import SwiftUI
import MapKit

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
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        request.region = region

        activeSearch = MKLocalSearch(request: request)
        activeSearch?.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                guard let response = response, error == nil else {
                    Log.error("Search", "MKLocalSearch failed: \(error?.localizedDescription ?? "unknown")")
                    return
                }
                self.searchResults = response.mapItems
            }
        }
    }
}

struct DestinationSearchView: View {
    @ObservedObject var searcher: DestinationSearcher
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var cameraStore: CameraStore
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var journal: RideJournal
    @EnvironmentObject var savedRoutes: SavedRoutesStore

    @Binding var routeState: RouteState
    @Binding var destinationName: String
    var onSearchFocused: (() -> Void)? = nil
    @FocusState private var isSearchFocused: Bool

    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 16) {
            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)

                TextField("Search Maps", text: $searcher.searchQuery)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .autocorrectionDisabled()
                    .onChange(of: searcher.searchQuery) { query in
                        searchTask?.cancel()
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                searcher.searchResults = []
                                searcher.isSearching = false
                            }
                            return
                        }
                        searcher.isSearching = true
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms debounce
                            guard !Task.isCancelled else { return }
                            searcher.search(for: query, near: owlPolice.currentLocation?.coordinate)
                        }
                    }
                    .onSubmit {
                        // Instant fire on keyboard Search key
                        searchTask?.cancel()
                        let query = searcher.searchQuery.trimmingCharacters(in: .whitespaces)
                        guard !query.isEmpty else { return }
                        searcher.isSearching = true
                        searcher.search(for: query, near: owlPolice.currentLocation?.coordinate)
                    }
                .font(.body)
                .foregroundColor(.primary)

                if !searcher.searchQuery.isEmpty {
                    Button(action: {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        searcher.searchQuery = ""
                        searcher.searchResults = []
                        searcher.isSearching = false
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44)
                    }
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.regularMaterial)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 16)

            // Empty query state: suggestions + recent + archive
            if searcher.searchQuery.isEmpty {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Quick Categories
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 20) {
                                CategoryButton(icon: "house.fill", title: "Home", color: .blue) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    searcher.searchQuery = "Home"
                                }
                                CategoryButton(icon: "briefcase.fill", title: "Work", color: .brown) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    searcher.searchQuery = "Work"
                                }
                                CategoryButton(icon: "fork.knife", title: "Restaurants", color: .orange) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    searcher.searchQuery = "Restaurants"
                                }
                                CategoryButton(icon: "fuelpump.fill", title: "Gas Stations", color: .indigo) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    searcher.searchQuery = "Gas Stations"
                                }
                                CategoryButton(icon: "cup.and.saucer.fill", title: "Coffee", color: .orange) {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    searcher.searchQuery = "Coffee"
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }

                        // Suggested section
                        let currentSuggestions = SmartSuggestionService.suggestions(from: savedRoutes)
                        if !currentSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Suggested")
                                    .font(.title3).fontWeight(.bold).foregroundColor(.primary)
                                    .padding(.horizontal)

                                VStack(spacing: 0) {
                                    ForEach(Array(currentSuggestions.enumerated()), id: \.element.id) { index, route in
                                        Button(action: { startRoutingToSaved(route) }) {
                                            HStack(spacing: 16) {
                                                ZStack {
                                                    Circle().fill(Color.yellow.opacity(0.15)).frame(width: 40, height: 40)
                                                    Image(systemName: "sparkles").font(.system(size: 18)).foregroundColor(.yellow)
                                                }
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(route.destinationName).font(.body).foregroundColor(.primary)
                                                    if let h = route.typicalDepartureHours.sorted().dropFirst(route.typicalDepartureHours.count / 4).first {
                                                        Text("Usually around \(formattedHour(h))")
                                                            .font(.subheadline).foregroundColor(.secondary)
                                                    }
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 12).padding(.horizontal, 16)
                                        }
                                        if index < currentSuggestions.count - 1 {
                                            Divider().padding(.leading, 60)
                                        }
                                    }
                                }
                                .background(.regularMaterial).cornerRadius(12).padding(.horizontal)
                            }
                            .padding(.top, 16)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Recent Routes section
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Recent Routes")
                                .font(.title3).fontWeight(.bold).foregroundColor(.primary)
                                .padding(.horizontal)

                            VStack(spacing: 0) {
                                FavoriteRow(icon: "plus", title: "Add", subtitle: "", color: .gray)

                                let recentRoutes = savedRoutes.topRecent(limit: 5)
                                if recentRoutes.isEmpty {
                                    Divider().padding(.leading, 60)
                                    HStack {
                                        Text("No routes recorded yet.")
                                            .font(.subheadline).foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding(.vertical, 16).padding(.horizontal, 16)
                                } else {
                                    ForEach(recentRoutes) { route in
                                        Divider().padding(.leading, 60)
                                        Button(action: { startRoutingToSaved(route) }) {
                                            HStack(spacing: 16) {
                                                ZStack {
                                                    Circle().fill(Color.blue.opacity(0.15)).frame(width: 40, height: 40)
                                                    Image(systemName: "mappin.circle.fill")
                                                        .font(.system(size: 20)).foregroundColor(.blue)
                                                }
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(route.destinationName).font(.body).foregroundColor(.primary)
                                                    Text(relativeDate(route.lastUsedDate))
                                                        .font(.subheadline).foregroundColor(.secondary)
                                                }
                                                Spacer()
                                                Image(systemName: "chevron.right").font(.caption.bold()).foregroundColor(.secondary)
                                            }
                                            .padding(.vertical, 12).padding(.horizontal, 16)
                                        }
                                    }
                                }
                            }
                            .background(.regularMaterial).cornerRadius(12).padding(.horizontal)
                        }
                        .padding(.top, 16)
                        .transition(.opacity)

                        // Ride Archive stats
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ride Archive")
                                .font(.title3).fontWeight(.bold).foregroundColor(.primary)
                                .padding(.horizontal)

                            if journal.entries.isEmpty && owlPolice.camerasPassedThisRide == 0 {
                                HStack {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Image(systemName: "car.2.fill").font(.title2).foregroundColor(.secondary)
                                        Text("No rides recorded.").font(.headline).foregroundColor(.primary)
                                        Text("Complete a trip to see your savings.").font(.subheadline).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding().background(.regularMaterial).cornerRadius(12).padding(.horizontal)
                            } else {
                                HStack(spacing: 16) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(systemName: "leaf.fill").font(.title2).foregroundColor(.green)
                                        Text("Saved").font(.subheadline).foregroundColor(.secondary)
                                        Text("$\((owlPolice.camerasPassedThisRide + journal.totalSaved / 100) * 100)")
                                            .font(.title3).fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding()
                                    .background(.regularMaterial).cornerRadius(12)

                                    VStack(alignment: .leading, spacing: 8) {
                                        Image(systemName: "car.fill").font(.title2).foregroundColor(.blue)
                                        Text("Trips").font(.subheadline).foregroundColor(.secondary)
                                        Text("\(journal.entries.count)").font(.title3).fontWeight(.bold)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading).padding()
                                    .background(.regularMaterial).cornerRadius(12)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.top, 16).padding(.bottom, 32)
                    }
                }
                .transition(.opacity)
            }

            // Search state: loading / no results / results
            if !searcher.searchQuery.isEmpty {
                Group {
                    if searcher.isSearching {
                        HStack { Spacer(); ProgressView(); Spacer() }
                            .padding(.vertical, 20)
                    } else if searcher.searchResults.isEmpty {
                        HStack {
                            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                            Text("No results for \"\(searcher.searchQuery)\"")
                                .font(.subheadline).foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding().background(.regularMaterial).cornerRadius(12).padding(.horizontal)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(Array(searcher.searchResults.enumerated()), id: \.offset) { index, item in
                                    Button(action: { startRouting(to: item) }) {
                                        HStack(spacing: 12) {
                                            ZStack {
                                                Circle().fill(Color.blue.opacity(0.12)).frame(width: 36, height: 36)
                                                Image(systemName: "mappin.circle.fill")
                                                    .font(.system(size: 18)).foregroundColor(.blue)
                                            }
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(item.name ?? "Unknown")
                                                    .font(.headline).foregroundColor(.primary)
                                                Text(item.placemark.title ?? "")
                                                    .font(.subheadline).foregroundColor(.secondary)
                                                    .lineLimit(1)
                                            }
                                            Spacer()
                                        }
                                        .padding(.vertical, 12).padding(.horizontal, 16)
                                    }
                                    if index < searcher.searchResults.count - 1 {
                                        Divider().padding(.leading, 60)
                                    }
                                }
                            }
                            .background(.regularMaterial).cornerRadius(16).padding(.horizontal)
                        }
                        .frame(maxHeight: 320)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searcher.isSearching)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searcher.searchResults.count)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Spacer()
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searcher.searchQuery.isEmpty)
        .onChange(of: isSearchFocused) { focused in
            if focused { onSearchFocused?() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .zenRideNavigateTo)) { note in
            if let route = note.object as? SavedRoute { startRoutingToSaved(route) }
        }
    }

    private func startRouting(to item: MKMapItem) {
        guard let destCoordinate = item.placemark.location?.coordinate else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let origin = owlPolice.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        destinationName = item.name ?? "Unknown Destination"
        Task { await routingService.calculateSafeRoute(from: origin, to: destCoordinate, avoiding: cameraStore.cameras) }
        searcher.searchResults = []
        searcher.searchQuery = ""
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { routeState = .reviewing }
    }

    private func startRoutingToSaved(_ route: SavedRoute) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let coord = CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude)
        let origin = owlPolice.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        destinationName = route.destinationName
        Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { routeState = .reviewing }
    }

    private func formattedHour(_ hour: Int) -> String {
        let period = hour < 12 ? "am" : "pm"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(h)\(period)"
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

struct CategoryButton: View {
    let icon: String
    let title: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle().fill(color).frame(width: 56, height: 56)
                    Image(systemName: icon).font(.title2).foregroundColor(.white)
                }
                Text(title).font(.caption).fontWeight(.medium).foregroundColor(.primary)
            }
        }
    }
}

struct FavoriteRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                ZStack {
                    Circle().fill(color.opacity(0.15)).frame(width: 40, height: 40)
                    Image(systemName: icon).font(.system(size: 20)).foregroundColor(color)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.body).foregroundColor(color == .gray ? .blue : .primary)
                    if !subtitle.isEmpty {
                        Text(subtitle).font(.subheadline).foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            .padding(.vertical, 12).padding(.horizontal, 16)
        }
    }
}
