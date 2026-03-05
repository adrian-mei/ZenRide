import SwiftUI
import MapKit

struct RecentsSection: View {
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    
    let onSelectDestination: (String, CLLocationCoordinate2D) -> Void

    var body: some View {
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
                            onSelectDestination(recent.name, CLLocationCoordinate2D(latitude: recent.latitude, longitude: recent.longitude))
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
}
