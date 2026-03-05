import SwiftUI
import MapKit

struct BookmarksSection: View {
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    
    let category: RoutineCategory?
    let categoryColor: (RoutineCategory?) -> Color
    let onSelectDestination: (String, CLLocationCoordinate2D) -> Void

    var body: some View {
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
                            onSelectDestination(route.destinationName, CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude))
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
}
