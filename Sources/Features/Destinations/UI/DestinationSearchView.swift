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
                            Text(item.placemark.zenFormattedAddress)
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
}

extension MKPlacemark {
    var zenFormattedAddress: String {
        var components: [String] = []
        var street = ""
        if let subThoroughfare = self.subThoroughfare { street += subThoroughfare + " " }
        if let thoroughfare = self.thoroughfare { street += thoroughfare }
        if !street.isEmpty { components.append(street) }
        if let city = self.locality { components.append(city) }
        else if let area = self.administrativeArea { components.append(area) }
        return components.isEmpty ? "Unknown Address" : components.joined(separator: ", ")
    }
}
