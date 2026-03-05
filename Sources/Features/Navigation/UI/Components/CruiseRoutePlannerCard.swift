import SwiftUI
import MapKit

struct CruiseRoutePlannerCard: View {
    @Binding var waypoints: [QuestWaypoint]
    @Binding var showAddStop: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ACSectionHeader(title: "ROUTE STOPS", icon: "map.fill", color: Theme.Colors.acLeaf)
                Spacer()
                Text("optional")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.acTextMuted)
            }

            if waypoints.isEmpty {
                emptyState
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(waypoints.enumerated()), id: \.element.id) { index, wp in
                        cruiseStopRow(index: index, wp: wp)
                    }
                }
            }

            Button {
                showAddStop = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill").font(Theme.Typography.body)
                    Text("Add a Stop").font(Theme.Typography.button)
                }
            }
            .buttonStyle(ACButtonStyle(variant: .secondary))
        }
        .acCardStyle(padding: 20)
    }
    
    private var emptyState: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.circle.fill")
                .font(Theme.Typography.title2)
                .foregroundColor(Theme.Colors.acSky)
            VStack(alignment: .leading, spacing: 2) {
                Text("Free Cruise")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                Text("Just drive — add stops to plan a shared route")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
        }
        .padding()
        .background(Theme.Colors.acCream)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.Colors.acBorder, lineWidth: 1.5))
    }

    @ViewBuilder
    private func cruiseStopRow(index: Int, wp: QuestWaypoint) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "\(index + 1).circle.fill")
                .foregroundColor(Theme.Colors.acLeaf)
                .font(Theme.Typography.title3)
            Image(systemName: wp.icon)
                .foregroundColor(Theme.Colors.acTextDark)
            Text(wp.name)
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextDark)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button {
                _ = waypoints.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.Colors.acCream)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.acBorder, lineWidth: 1))
    }
}
