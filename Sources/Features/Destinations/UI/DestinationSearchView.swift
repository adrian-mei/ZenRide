import SwiftUI
import MapKit
import CoreLocation

// MARK: - DestinationSearchView

struct DestinationSearchView: View {
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var cameraStore: CameraStore
    @Environment(\.dismiss) private var dismiss

    var category: RoutineCategory?
    var slotIndex: Int?
    var onDestinationSelected: (String, CLLocationCoordinate2D) -> Void

    init(category: RoutineCategory? = nil, slotIndex: Int? = nil, onDestinationSelected: @escaping (String, CLLocationCoordinate2D) -> Void) {
        self.category = category
        self.slotIndex = slotIndex
        self.onDestinationSelected = onDestinationSelected
    }

    @StateObject private var searcher = DestinationSearcher()
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()

                VStack(spacing: 0) {
                    searchBar
                    
                    if let category = category {
                        categoryFilterIndicator(category)
                    }

                    if !searcher.searchQuery.isEmpty || category != nil {
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
            .navigationTitle(category != nil ? "Assign \(category!.displayName)" : "Find a Spot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
            .onAppear {
                searcher.category = category
                isSearchFocused = true
                if category != nil && searcher.searchQuery.isEmpty {
                    searcher.search(for: "", near: locationProvider.currentLocation?.coordinate, recentSearches: savedRoutes.recentSearches)
                }
            }
        }
    }

    // MARK: - Components
    
    private var searchBar: some View {
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
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: searcher.searchQuery.isEmpty)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
        }
        .padding()
    }
    
    private func categoryFilterIndicator(_ category: RoutineCategory) -> some View {
        HStack {
            Label("Filtering for \(category.displayName)", systemImage: category.icon)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(categoryColor(category))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(categoryColor(category).opacity(0.12))
        .clipShape(Capsule())
        .padding(.horizontal)
        .padding(.bottom, 8)
    }

    private var bookmarksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            ACSectionHeader(title: "BOOKMARKS", icon: "bookmark.fill", color: Theme.Colors.acCoral)
                .padding(.horizontal)

            let pinned = savedRoutes.pinnedRoutes.filter { route in
                if let cat = category {
                    return route.category == cat
                }
                return true
            }

            if pinned.isEmpty {
                Text(category != nil ? "No bookmarked \(category!.displayName) yet." : "No bookmarked spots yet.")
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
                        let distanceString: String? = {
                            guard let userLoc = locationProvider.currentLocation, let placeLoc = item.placemark.location else { return nil }
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
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searcher.isSearching)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: searcher.searchResults.isEmpty)
    }

    // MARK: - Actions

    private func selectDestination(name: String, coordinate: CLLocationCoordinate2D, placemark: MKPlacemark? = nil) {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        // Save to recents
        let subtitle = placemark?.zenFormattedAddress ?? "Saved Destination"

        if let category = category, let slotIndex = slotIndex {
            savedRoutes.saveAndAssignToRoutine(name: name, coordinate: coordinate, category: category, index: slotIndex)
        } else {
            savedRoutes.addRecentSearch(name: name, subtitle: subtitle, coordinate: coordinate)
        }

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
        case .grocery: return Theme.Colors.acLeaf
        case .coffee: return Theme.Colors.acWood
        }
    }
}
