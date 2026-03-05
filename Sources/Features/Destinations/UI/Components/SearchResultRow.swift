import SwiftUI
import MapKit

struct SearchResultRow: View {
    let item: MKMapItem
    let isSaved: Bool
    let distanceString: String?
    let action: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: action) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acLeaf.opacity(0.15))
                            .frame(width: 42, height: 42)
                        Image(systemName: "mappin.circle.fill")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.acLeaf)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name ?? "Unknown")
                            .font(Theme.Typography.headline)
                            .foregroundStyle(Theme.Colors.acTextDark)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(alignment: .top, spacing: 6) {
                            Text(item.placemark.zenFormattedAddress)
                                .font(Theme.Typography.body)
                                .foregroundStyle(Theme.Colors.acWood)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)

                            if let dist = distanceString {
                                Text(dist)
                                    .font(Theme.Typography.caption)
                                    .foregroundStyle(Theme.Colors.acSky)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 2)
                                    .background(Theme.Colors.acSky.opacity(0.18))
                                    .clipShape(Capsule())
                                    .layoutPriority(1)
                            }
                        }
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onSave) {
                ZStack {
                    Image(systemName: "bookmark.fill")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.acWood)
                        .scaleEffect(isSaved ? 1 : 0.01)
                        .opacity(isSaved ? 1 : 0)

                    Image(systemName: "bookmark")
                        .font(Theme.Typography.headline)
                        .foregroundStyle(Theme.Colors.acWood)
                        .scaleEffect(isSaved ? 0.01 : 1)
                        .opacity(isSaved ? 0 : 1)
                }
                .frame(width: 50, height: 50)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSaved)
            }
            .buttonStyle(ACRowButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}
