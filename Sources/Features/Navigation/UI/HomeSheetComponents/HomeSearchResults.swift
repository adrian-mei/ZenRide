import SwiftUI
import MapKit
import CoreLocation

struct HomeSearchResults: View {
    let isSearching: Bool
    let searchQuery: String
    let searchResults: [MKMapItem]
    let currentLocation: CLLocation?
    
    // Actions
    let isPlaceSaved: (String, CLLocationCoordinate2D) -> Bool
    let onRouteTo: (MKMapItem) -> Void
    let onSavePlace: (MKMapItem) -> Void
    let onAddToTripBuilder: (MKMapItem) -> Void

    var body: some View {
        if isSearching {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(Theme.Colors.acWood)
                Text("Searching…")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.acWood)
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .transition(.opacity)
        } else if searchResults.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(Theme.Colors.acTextMuted)
                Text("No results for \"\(searchQuery)\"")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.acTextMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .transition(.opacity)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(searchResults.prefix(12).enumerated()), id: \.offset) { idx, item in
                    let distanceString: String? = {
                        guard let currentLocation, let placeLoc = item.placemark.location else { return nil }
                        let miles = currentLocation.distance(from: placeLoc) / 1609.34
                        return miles < 0.1 ? "Nearby" : String(format: "%.1f mi", miles)
                    }()
                    
                    HStack(spacing: 0) {
                        SearchResultRow(
                            item: item,
                            isSaved: isPlaceSaved(item.name ?? "", item.placemark.coordinate),
                            distanceString: distanceString
                        ) {
                            onRouteTo(item)
                        } onSave: {
                            onSavePlace(item)
                        }

                        // "+" pill — add to trip builder
                        Button {
                            onAddToTripBuilder(item)
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acLeaf)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 10)
                    }

                    if idx < min(searchResults.count, 12) - 1 {
                        ACSectionDivider(leadingInset: 66)
                    }
                }
            }
            .background(Theme.Colors.acField)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
            .padding(.bottom, 20)
            .transition(.opacity)
        }
    }
}
