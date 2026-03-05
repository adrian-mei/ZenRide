import SwiftUI

struct CenterView<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack {
            Spacer()
            content()
            Spacer()
        }
    }
}

struct RecentRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconColor: Color = Theme.Colors.acLeaf
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(Theme.Typography.body)
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(Theme.Typography.caption)
                    .foregroundStyle(Theme.Colors.acBorder)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct BookmarkRouteCard: View {
    let route: SavedRoute
    var isLoading: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "bookmark.fill")
                        .font(Theme.Typography.button)
                        .foregroundColor(Theme.Colors.acCoral)
                    Spacer()
                    if route.offlineRoute != nil {
                        Text("Offline")
                            .font(Theme.Typography.label)
                            .foregroundColor(Theme.Colors.acSky)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.acSky.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                Text(route.destinationName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .frame(width: 160, height: 110)
            .padding(14)
            .background(Theme.Colors.acField)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Colors.acBorder, lineWidth: 2))
            .shadow(color: Theme.Colors.acBorder.opacity(0.8), radius: 0, x: 0, y: 4)
            .overlay(
                Group {
                    if isLoading {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Theme.Colors.acCream.opacity(0.85))
                        ProgressView().tint(Theme.Colors.acLeaf)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

extension UIApplication {
    var firstKeyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }
}
