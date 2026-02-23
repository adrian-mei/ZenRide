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
    @State private var justSaved: UUID? = nil  // flash confirmation on save

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            searchBar
                .padding(.top, 20)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Divider().opacity(0.3)

            if searcher.searchQuery.isEmpty {
                idleContent
            } else {
                searchResultsContent
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: searcher.searchQuery.isEmpty)
        .onChange(of: isSearchFocused) { focused in
            if focused { onSearchFocused?() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .zenRideNavigateTo)) { note in
            if let route = note.object as? SavedRoute { startRoutingToSaved(route) }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 17, weight: .medium))

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
                        try? await Task.sleep(nanoseconds: 180_000_000) // 180ms
                        guard !Task.isCancelled else { return }
                        searcher.search(for: query, near: owlPolice.currentLocation?.coordinate)
                    }
                }
                .onSubmit {
                    searchTask?.cancel()
                    let q = searcher.searchQuery.trimmingCharacters(in: .whitespaces)
                    guard !q.isEmpty else { return }
                    searcher.isSearching = true
                    searcher.search(for: q, near: owlPolice.currentLocation?.coordinate)
                }

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
                        .frame(width: 44, height: 36)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Idle Content (no query)

    private var idleContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Quick categories
                categoryRow
                    .padding(.vertical, 16)

                Divider().opacity(0.3)

                // Smart suggestions
                let suggestions = SmartSuggestionService.suggestions(from: savedRoutes)
                if !suggestions.isEmpty {
                    SectionHeader(title: "Suggested", icon: "sparkles", iconColor: .yellow)
                    ForEach(suggestions) { route in
                        RouteRow(
                            icon: "sparkles",
                            iconColor: .yellow,
                            title: route.destinationName,
                            subtitle: typicalTimeLabel(route),
                            trailingIcon: nil
                        ) {
                            startRoutingToSaved(route)
                        }
                        .contentShape(Rectangle())
                    }
                    Divider().padding(.leading, 60).opacity(0.3)
                }

                // Saved / Pinned places
                let pinned = savedRoutes.pinnedRoutes
                SectionHeader(title: "Saved Places", icon: "star.fill", iconColor: .orange)
                if pinned.isEmpty {
                    emptyPlaceholder(
                        icon: "star",
                        message: "Save a place to find it here",
                        subMessage: "Tap ⋯ on any search result"
                    )
                } else {
                    ForEach(pinned) { route in
                        RouteRow(
                            icon: "star.fill",
                            iconColor: .orange,
                            title: route.destinationName,
                            subtitle: route.useCount > 0 ? relativeDate(route.lastUsedDate) : "Saved place",
                            trailingIcon: "chevron.right"
                        ) {
                            startRoutingToSaved(route)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation { savedRoutes.deleteRoute(id: route.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation { savedRoutes.togglePin(id: route.id) }
                            } label: {
                                Label("Unsave", systemImage: "star.slash")
                            }
                            .tint(.gray)
                        }
                    }
                }

                Divider().padding(.leading, 60).opacity(0.3)

                // Recent routes (visited but not pinned)
                let recent = savedRoutes.topRecent(limit: 6).filter { !$0.isPinned }
                if !recent.isEmpty {
                    SectionHeader(title: "Recent", icon: "clock", iconColor: .secondary)
                    ForEach(recent) { route in
                        RouteRow(
                            icon: "clock.arrow.circlepath",
                            iconColor: .secondary,
                            title: route.destinationName,
                            subtitle: relativeDate(route.lastUsedDate),
                            trailingIcon: "chevron.right"
                        ) {
                            startRoutingToSaved(route)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                withAnimation { savedRoutes.deleteRoute(id: route.id) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation { savedRoutes.togglePin(id: route.id) }
                            } label: {
                                Label("Save", systemImage: "star")
                            }
                            .tint(.orange)
                        }
                    }
                    Divider().padding(.leading, 60).opacity(0.3)
                }

                Spacer(minLength: 40)
            }
        }
        .transition(.opacity)
    }

    // MARK: - Search Results

    private var searchResultsContent: some View {
        Group {
            if searcher.isSearching {
                VStack {
                    Spacer()
                    ProgressView("Searching…")
                    Spacer()
                }
                .transition(.opacity)
            } else if searcher.searchResults.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No results for \"\(searcher.searchQuery)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
                .transition(.opacity)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(searcher.searchResults.enumerated()), id: \.offset) { _, item in
                            SearchResultRow(item: item, isSaved: justSaved == nil) {
                                startRouting(to: item)
                            } onSave: {
                                guard let coord = item.placemark.location?.coordinate else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                savedRoutes.savePlace(name: item.name ?? "Place", coordinate: coord)
                                withAnimation { justSaved = UUID() }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    withAnimation { justSaved = nil }
                                }
                            }
                        }
                    }
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searcher.isSearching)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: searcher.searchResults.count)
    }

    // MARK: - Category Row

    private var categoryRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                CategoryChip(icon: "house.fill", title: "Home", color: .blue) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searcher.searchQuery = "Home"
                }
                CategoryChip(icon: "briefcase.fill", title: "Work", color: .brown) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searcher.searchQuery = "Work"
                }
                CategoryChip(icon: "fork.knife", title: "Food", color: .orange) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searcher.searchQuery = "Restaurants"
                }
                CategoryChip(icon: "fuelpump.fill", title: "Gas", color: .indigo) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searcher.searchQuery = "Gas Stations"
                }
                CategoryChip(icon: "cup.and.saucer.fill", title: "Coffee", color: .brown) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searcher.searchQuery = "Coffee"
                }
                CategoryChip(icon: "cross.fill", title: "Hospital", color: .red) {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    searcher.searchQuery = "Hospital"
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // MARK: - Helpers

    private func emptyPlaceholder(icon: String, message: String, subMessage: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: icon).foregroundColor(.secondary)
                    Text(message).font(.subheadline).foregroundColor(.secondary)
                }
                Text(subMessage).font(.caption).foregroundColor(Color.secondary.opacity(0.6))
            }
            Spacer()
        }
        .padding(.horizontal, 60)
        .padding(.vertical, 14)
    }

    private func startRouting(to item: MKMapItem) {
        guard let coord = item.placemark.location?.coordinate else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let origin = owlPolice.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        destinationName = item.name ?? "Destination"
        Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
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

    private func typicalTimeLabel(_ route: SavedRoute) -> String {
        guard let h = route.typicalDepartureHours.sorted()
            .dropFirst(route.typicalDepartureHours.count / 4).first else { return "Frequently visited" }
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

// MARK: - Section Header

private struct SectionHeader: View {
    let title: String
    let icon: String
    let iconColor: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 6)
    }
}

// MARK: - Route Row (for saved/recent sections)

private struct RouteRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let trailingIcon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.12))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if let trailing = trailingIcon {
                    Image(systemName: trailing)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
    }
}

// MARK: - Search Result Row

private struct SearchResultRow: View {
    let item: MKMapItem
    let isSaved: Bool
    let action: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Button(action: action) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 38, height: 38)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name ?? "Unknown")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Text(item.placemark.locality ?? item.placemark.title ?? "")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }

            // Save button
            Button(action: onSave) {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - Category Chip

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
                    Image(systemName: icon).font(.title3).foregroundColor(.white)
                }
                Text(title).font(.caption).fontWeight(.medium).foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Legacy aliases (GarageView uses these names)
typealias CategoryButton = CategoryChip

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
