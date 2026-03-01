import SwiftUI
import MapKit
import CoreLocation

// MARK: - Searcher

class DestinationSearcher: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false

    private var activeSearch: MKLocalSearch?
    private var searchTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    /// Debounced search — cancels any pending search and waits 200ms before firing.
    /// Call this from `.onChange`; call `search(for:)` directly from `.onSubmit`.
    func scheduleSearch(for query: String, near location: CLLocationCoordinate2D? = nil, recentSearches: [RecentSearch] = []) {
        debounceTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        isSearching = true
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled else { return }
            search(for: trimmed, near: location, recentSearches: recentSearches)
        }
    }

    func search(for query: String, near location: CLLocationCoordinate2D? = nil, recentSearches: [RecentSearch] = []) {
        activeSearch?.cancel()
        searchTask?.cancel()
        
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        guard !cleanQuery.isEmpty else {
            searchResults = []; isSearching = false; return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = cleanQuery
        let center = location ?? Constants.sfCenter
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        
        let lowerQuery = cleanQuery.lowercased()
        let matchedRecents = recentSearches.filter { recent in
            recent.name.lowercased().contains(lowerQuery) ||
            recent.subtitle.lowercased().contains(lowerQuery)
        }.map { recent -> MKMapItem in
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: recent.latitude, longitude: recent.longitude),
                                        addressDictionary: ["Street": recent.subtitle])
            let item = MKMapItem(placemark: placemark)
            item.name = recent.name
            return item
        }

        let search = MKLocalSearch(request: request)
        activeSearch = search
        
        searchTask = Task { @MainActor [weak self] in
            guard let self = self else { return }
            
            do {
                // Run geocoding and search concurrently
                let clLocation = CLLocation(latitude: center.latitude, longitude: center.longitude)
                
                async let geocodeResult = try? CLGeocoder().reverseGeocodeLocation(clLocation)
                async let searchResult = try? search.start()
                
                let (placemarks, response) = await (geocodeResult, searchResult)
                
                if Task.isCancelled { return }
                
                self.isSearching = false
                
                guard let response = response else {
                    if !matchedRecents.isEmpty {
                        self.searchResults = matchedRecents
                    } else {
                        Log.error("Search", "MKLocalSearch failed")
                    }
                    return
                }
                
                let userCity = placemarks?.first?.locality?.lowercased()
                
                let sortedNetworkResults = response.mapItems.sorted { item1, item2 in
                    let name1 = (item1.name ?? "").lowercased()
                    let name2 = (item2.name ?? "").lowercased()
                    
                    let score1 = Self.score(name: name1, query: lowerQuery)
                    let score2 = Self.score(name: name2, query: lowerQuery)
                    
                    if score1 != score2 {
                        return score1 > score2
                    }
                    
                    if let userCity = userCity {
                        let city1 = item1.placemark.locality?.lowercased()
                        let city2 = item2.placemark.locality?.lowercased()
                        
                        let isCity1Match = city1 == userCity
                        let isCity2Match = city2 == userCity
                        
                        if isCity1Match && !isCity2Match {
                            return true
                        } else if !isCity1Match && isCity2Match {
                            return false
                        }
                    }
                    
                    guard let loc1 = item1.placemark.location, let loc2 = item2.placemark.location else {
                        return false
                    }
                    let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    return loc1.distance(from: centerLoc) < loc2.distance(from: centerLoc)
                }
                
                var finalResults = matchedRecents
                var seenCoordinates = Set<String>()
                
                // Keep track of coordinates we've already added (from recents)
                for r in matchedRecents {
                    let coordStr = "\(String(format: "%.4f", r.placemark.coordinate.latitude)),\(String(format: "%.4f", r.placemark.coordinate.longitude))"
                    seenCoordinates.insert(coordStr)
                }
                
                for item in sortedNetworkResults {
                    let coordStr = "\(String(format: "%.4f", item.placemark.coordinate.latitude)),\(String(format: "%.4f", item.placemark.coordinate.longitude))"
                    
                    if !seenCoordinates.contains(coordStr) {
                        finalResults.append(item)
                        seenCoordinates.insert(coordStr)
                    }
                }
                
                self.searchResults = finalResults
            } catch {
                if !Task.isCancelled {
                    self.isSearching = false
                }
            }
        }
    }
    
    private static func score(name: String, query: String) -> Int {
        if name == query { return 4 }
        if name.hasPrefix(query) { return 3 }
        if name.contains(query) { return 2 }
        return 1
    }
}

// MARK: - DestinationSearchView

struct DestinationSearchView: View {
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var cameraStore: CameraStore
    @Environment(\.dismiss) private var dismiss

    var onDestinationSelected: (String, CLLocationCoordinate2D) -> Void

    init(onDestinationSelected: @escaping (String, CLLocationCoordinate2D) -> Void) {
        self.onDestinationSelected = onDestinationSelected
    }

    @StateObject private var searcher = DestinationSearcher()
    @FocusState private var isSearchFocused: Bool
    @State private var justSavedIndex: Int? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search bar
                    HStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(Theme.Colors.acTextMuted)
                                .font(.system(size: 16, weight: .bold))

                            TextField("Where to?", text: $searcher.searchQuery)
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                                .autocorrectionDisabled()
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.acTextDark)
                                .onChange(of: searcher.searchQuery) { _, query in
                                    searcher.scheduleSearch(for: query, near: locationProvider.currentLocation?.coordinate, recentSearches: savedRoutes.recentSearches)
                                }
                                .onSubmit {
                                    let q = searcher.searchQuery.trimmingCharacters(in: .whitespaces)
                                    guard !q.isEmpty else { return }
                                    searcher.search(for: q, near: locationProvider.currentLocation?.coordinate, recentSearches: savedRoutes.recentSearches)
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
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.acCream)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
                    }
                    .padding()

                    // Content
                    if !searcher.searchQuery.isEmpty {
                        searchResultsList
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 24) {
                                bookmarksSection
                                recentsSection
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            .navigationTitle("Find a Spot")
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

    // MARK: - Sections

    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ACSectionHeader(title: "BOOKMARKS", icon: "bookmark.fill", color: Theme.Colors.acCoral)
                .padding(.horizontal)

            let pinned = savedRoutes.pinnedRoutes
            if pinned.isEmpty {
                Text("No bookmarked spots yet.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(pinned.prefix(8).enumerated()), id: \.offset) { idx, route in
                        SavedRouteRow(
                            systemIcon: route.category?.icon ?? "mappin.circle.fill",
                            iconColor: categoryColor(route.category),
                            title: route.destinationName,
                            subtitle: route.category?.displayName ?? "Saved Place"
                        ) {
                            selectDestination(name: route.destinationName, coordinate: CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude))
                        }
                        
                        if idx < min(pinned.count, 8) - 1 {
                            ACSectionDivider(leadingInset: 64)
                        }
                    }
                }
                .acCardStyle(padding: 0)
                .padding(.horizontal)
            }
        }
    }

    private var recentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ACSectionHeader(title: "RECENT SEARCHES", icon: "clock.fill", color: Theme.Colors.acTextMuted)
                .padding(.horizontal)

            let recents = savedRoutes.recentSearches
            if recents.isEmpty {
                Text("Your recent destinations will appear here.")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .padding(.horizontal)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(recents.prefix(5).enumerated()), id: \.offset) { idx, recent in
                        SavedRouteRow(
                            systemIcon: "clock.fill",
                            iconColor: Theme.Colors.acTextMuted,
                            title: recent.name,
                            subtitle: recent.subtitle
                        ) {
                            selectDestination(name: recent.name, coordinate: CLLocationCoordinate2D(latitude: recent.latitude, longitude: recent.longitude))
                        }
                        
                        if idx < min(recents.count, 5) - 1 {
                            ACSectionDivider(leadingInset: 64)
                        }
                    }
                }
                .acCardStyle(padding: 0)
                .padding(.horizontal)
            }
        }
    }

    private var searchResultsList: some View {
        ScrollView {
            if searcher.isSearching {
                VStack(spacing: 12) {
                    ProgressView().scaleEffect(1.4).tint(Theme.Colors.acWood)
                    Text("Searching…").font(Theme.Typography.body).foregroundStyle(Theme.Colors.acWood)
                }
                .padding(.top, 40)
            } else if searcher.searchResults.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").font(.system(size: 32)).foregroundStyle(Theme.Colors.acTextMuted)
                    Text("No results for \"\(searcher.searchQuery)\"").font(Theme.Typography.body).foregroundStyle(Theme.Colors.acTextMuted)
                }
                .padding(.top, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(searcher.searchResults.prefix(12).enumerated()), id: \.offset) { idx, item in
                        let userLoc = locationProvider.currentLocation
                        let distanceString: String? = {
                            guard let userLoc, let placeLoc = item.placemark.location else { return nil }
                            let miles = userLoc.distance(from: placeLoc) / Constants.metersPerMile
                            return miles < 0.1 ? "Nearby" : String(format: "%.1f mi", miles)
                        }()
                        
                        SearchResultRow(
                            item: item,
                            isSaved: savedRoutes.isPlaceSaved(name: item.name ?? "", coordinate: item.placemark.coordinate),
                            distanceString: distanceString
                        ) {
                            selectDestination(name: item.name ?? "Destination", coordinate: item.placemark.coordinate, placemark: item.placemark)
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

                        if idx < min(searcher.searchResults.count, 12) - 1 {
                            ACSectionDivider(leadingInset: 66)
                        }
                    }
                }
                .acCardStyle(padding: 0)
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Actions

    private func selectDestination(name: String, coordinate: CLLocationCoordinate2D, placemark: MKPlacemark? = nil) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        
        // Save to recents
        let subtitle = placemark?.zenFormattedAddress ?? "Saved Destination"
        savedRoutes.addRecentSearch(name: name, subtitle: subtitle, coordinate: coordinate)
        
        // Start navigation directly (single destination mission)
        onDestinationSelected(name, coordinate)
        dismiss()
    }

    private func categoryColor(_ category: RoutineCategory?) -> Color {
        guard let category = category else { return Theme.Colors.acLeaf }
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
}

// MARK: - Row Components (extracted from previous file)

struct SavedRouteRow: View {
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
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: systemIcon)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.Colors.acTextDark)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.Colors.acWood)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.Colors.acBorder)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct SearchResultRow: View {
    let item: MKMapItem
    let isSaved: Bool
    let distanceString: String?
    let action: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acLeaf.opacity(0.15))
                            .frame(width: 42, height: 42)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.Colors.acLeaf)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Unknown")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.Colors.acTextDark)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(item.placemark.zenFormattedAddress)
                                .font(.system(size: 14, design: .rounded))
                                .foregroundStyle(Theme.Colors.acWood)
                                .lineLimit(1)
                            if let dist = distanceString {
                                Text(dist)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(Theme.Colors.acSky)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Theme.Colors.acSky.opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onSave) {
                ZStack {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Colors.acWood)
                        .scaleEffect(isSaved ? 1 : 0.01)
                        .opacity(isSaved ? 1 : 0)

                    Image(systemName: "bookmark")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Colors.acWood)
                        .scaleEffect(isSaved ? 0.01 : 1)
                        .opacity(isSaved ? 0 : 1)
                }
                .frame(width: 50, height: 50)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSaved)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

extension MKPlacemark {
    var zenFormattedAddress: String {
        var components: [String] = []
        var street = ""
        if let subThoroughfare = self.subThoroughfare { street += subThoroughfare + " " }
        if let thoroughfare = self.thoroughfare { street += thoroughfare }
        
        if !street.isEmpty { components.append(street) }
        else if let title = self.title {
            return title
        }
        
        if let city = self.locality { components.append(city) }
        else if let area = self.administrativeArea { components.append(area) }
        
        return components.isEmpty ? "Unknown Address" : components.joined(separator: ", ")
    }
}
