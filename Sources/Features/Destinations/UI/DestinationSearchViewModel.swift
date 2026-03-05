import SwiftUI
import MapKit
import CoreLocation

// MARK: - Searcher

class DestinationSearcher: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false

    var category: RoutineCategory?

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
        let effectiveQuery = cleanQuery.isEmpty ? (category?.displayName ?? "") : cleanQuery

        guard !effectiveQuery.isEmpty else {
            searchResults = []; isSearching = false; return
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = effectiveQuery

        // Apply intelligence based on category
        if let category = category {
            switch category {
            case .home, .work:
                // User is likely searching for an address, filter out POIs to avoid "Home Depot" etc.
                request.pointOfInterestFilter = .excludingAll
            case .gym:
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.fitnessCenter])
            case .school, .dayCare, .afterSchool:
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.school, .university])
            case .dateSpot:
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.restaurant, .cafe, .theater, .movieTheater, .museum, .park])
            case .holySpot:
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.park, .beach, .nationalPark])
            case .grocery:
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.store, .foodMarket, .bakery])
            case .coffee:
                request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])
            default:
                break
            }
        }

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

            let filteredNetworkResults = response.mapItems.filter { item in
                guard let cat = self.category else { return true }

                // Always allow results that strongly match the user's manual query
                if !lowerQuery.isEmpty {
                    let name = (item.name ?? "").lowercased()
                    if name.contains(lowerQuery) || lowerQuery.contains(name) {
                        return true
                    }
                }

                switch cat {
                case .home, .work:
                    return item.pointOfInterestCategory == nil
                case .gym:
                    return item.pointOfInterestCategory == .fitnessCenter
                case .school, .dayCare, .afterSchool:
                    return item.pointOfInterestCategory == .school || item.pointOfInterestCategory == .university
                case .dateSpot:
                    let dateCategories: [MKPointOfInterestCategory] = [.restaurant, .cafe, .theater, .movieTheater, .museum, .park]
                    if let itemCat = item.pointOfInterestCategory {
                        return dateCategories.contains(itemCat)
                    }
                    return false
                case .holySpot:
                    let zenCategories: [MKPointOfInterestCategory] = [.park, .beach, .nationalPark]
                    if let itemCat = item.pointOfInterestCategory {
                        return zenCategories.contains(itemCat)
                    }
                    return false
                case .grocery:
                    let groceryCategories: [MKPointOfInterestCategory] = [.store, .foodMarket, .bakery]
                    if let itemCat = item.pointOfInterestCategory {
                        return groceryCategories.contains(itemCat)
                    }
                    return false
                case .coffee:
                    return item.pointOfInterestCategory == .cafe
                default:
                    return true
                }
            }

            let sortedNetworkResults = filteredNetworkResults.sorted { item1, item2 in

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
        }
    }

    static func score(name: String, query: String) -> Int {
        if name == query { return 4 }
        if name.hasPrefix(query) { return 3 }
        if name.contains(query) { return 2 }
        return 1
    }
}
