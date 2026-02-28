import SwiftUI
import MapKit

// MARK: - Searcher

class DestinationSearcher: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [MKMapItem] = []
    @Published var isSearching = false

    private var activeSearch: MKLocalSearch?
    private var searchTask: Task<Void, Never>?

    func search(for query: String, near location: CLLocationCoordinate2D? = nil, recentSearches: [RecentSearch] = []) {
        activeSearch?.cancel()
        searchTask?.cancel()
        
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        guard !cleanQuery.isEmpty else {
            searchResults = []; isSearching = false; return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = cleanQuery
        let center = location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
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
                    
                    // Don't deduplicate simply by name, as there can be multiple branches of a store.
                    // Deduplicate by approximate location to avoid showing the exact same physical place twice.
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

// MARK: - RouteListRow (used in List — gets native separators + swipe)

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
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.Colors.acTextDark)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Colors.acTextMuted)
                        .lineLimit(1)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - SearchResultRow

struct SearchResultRow: View {
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
                            .fill(Theme.Colors.acLeaf.opacity(0.15))
                            .frame(width: 42, height: 42)
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Theme.Colors.acLeaf)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Unknown")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.Colors.acTextDark)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text(item.placemark.zenFormattedAddress)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.Colors.acTextMuted)
                                .lineLimit(1)
                            if let dist = distanceString {
                                Text(dist)
                                    .font(.system(size: 11, weight: .bold))
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

            // Bookmark save button — shows filled bookmark when saved
            Button(action: onSave) {
                ZStack {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Colors.acCoral)
                        .scaleEffect(isSaved ? 1 : 0.01)
                        .opacity(isSaved ? 1 : 0)

                    Image(systemName: "bookmark")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.Colors.acTextMuted)
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
}

extension MKPlacemark {
    var zenFormattedAddress: String {
        var components: [String] = []
        var street = ""
        if let subThoroughfare = self.subThoroughfare { street += subThoroughfare + " " }
        if let thoroughfare = self.thoroughfare { street += thoroughfare }
        
        // Use custom title logic if we set it from RecentSearch
        if let dict = self.title, street.isEmpty {
            // We use title field implicitly when name/address falls back for recents, or we can just parse title
        }
        // Let's fallback to the basic properties, as addressDictionary is deprecated. 
        // MKPlacemark's title is often exactly what we want if other properties fail.
        
        if !street.isEmpty { components.append(street) }
        else if let title = self.title {
            // MKPlacemark.title usually contains the formatted address
            return title
        }
        
        if let city = self.locality { components.append(city) }
        else if let area = self.administrativeArea { components.append(area) }
        
        return components.isEmpty ? "Unknown Address" : components.joined(separator: ", ")
    }
}