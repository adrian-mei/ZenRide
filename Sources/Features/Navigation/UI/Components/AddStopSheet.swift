import SwiftUI
import MapKit

struct AddStopSheet: View {
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var savedRoutes: SavedRoutesStore

    @Environment(\.dismiss) private var dismiss

    let onSelect: (QuestWaypoint) -> Void

    @StateObject private var searcher = DestinationSearcher()
    @FocusState private var isSearchFocused: Bool

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
                                searcher.scheduleSearch(for: query, near: locationProvider.currentLocation?.coordinate, recentSearches: savedRoutes.recentSearches)
                            }
                            .onSubmit {
                                let q = searcher.searchQuery.trimmingCharacters(in: .whitespaces)
                                guard !q.isEmpty else { return }
                                searcher.search(for: q, near: locationProvider.currentLocation?.coordinate, recentSearches: savedRoutes.recentSearches)
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
                                        let miles = userLoc.distance(from: placeLoc) / Constants.metersPerMile
                                        return miles < 0.1 ? "Nearby" : String(format: "%.1f mi", miles)
                                    }()
                                    SearchResultRow(
                                        item: item,
                                        isSaved: savedRoutes.isPlaceSaved(name: item.name ?? "", coordinate: item.placemark.coordinate),
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
