import SwiftUI
import MapKit
import CoreLocation

// MARK: - Searcher

@MainActor
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
        
        let center = location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        var userCity: String? = nil
        let geocoder = CLGeocoder()
        let clLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)

        searchTask = Task {
            isSearching = true
            defer { isSearching = false }

            let placemarks = try? await geocoder.reverseGeocodeLocation(clLoc)
            userCity = placemarks?.first?.locality?.lowercased()

            let lowerQuery = cleanQuery.lowercased()

            var matchedRecents = [MKMapItem]()
            if !lowerQuery.isEmpty {
                matchedRecents = recentSearches
                    .filter { $0.name.lowercased().contains(lowerQuery) }
                    .prefix(2)
                    .map { MKMapItem(placemark: MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude))) }
            }

            if cleanQuery.isEmpty && category != nil {
                // Return just recents matching the category context, or empty if no query
                // The view will handle showing the empty state or default categories
                searchResults = matchedRecents
                return
            }

            let request = MKLocalSearch.Request()
            request.naturalLanguageQuery = cleanQuery

            if let category = category {
                switch category {
                case .home:
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: []) // Address search mostly
                case .work:
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [])
                case .gym:
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.fitnessCenter])
                case .holySpot:
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.park, .beach, .nationalPark])
                case .school, .afterSchool:
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.school, .university])
                case .grocery:
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.store, .foodMarket, .bakery])
                case .coffee:
                    request.pointOfInterestFilter = MKPointOfInterestFilter(including: [.cafe])
                default:
                    request.pointOfInterestFilter = .includingAll
                }
            } else {
                request.pointOfInterestFilter = .includingAll
            }

            request.region = MKCoordinateRegion(center: center, latitudinalMeters: 50000, longitudinalMeters: 50000)

            activeSearch = MKLocalSearch(request: request)

            guard let response = try? await activeSearch?.start() else {
                if !Task.isCancelled {
                    self.searchResults = matchedRecents
                }
                return
            }

            if Task.isCancelled { return }

            let filteredNetworkResults = response.mapItems.filter { item in
                guard let category = category else { return true }
                switch category {
                case .gym:
                    return item.pointOfInterestCategory == .fitnessCenter
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

    nonisolated
    static func score(name: String, query: String) -> Int {
        if name == query { return 4 }
        if name.hasPrefix(query) { return 3 }
        if name.contains(query) { return 2 }
        return 1
    }
}
