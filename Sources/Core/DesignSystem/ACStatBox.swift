import SwiftUI

// MARK: - ACStatBox

/// Card-style stat box showing an optional icon, a value, and a label.
public struct ACStatBox: View {
    let title: String
    let value: String
    var icon: String?
    var iconColor: Color = Theme.Colors.acLeaf
    var padding: CGFloat = 16

    public init(title: String, value: String, icon: String? = nil, iconColor: Color = Theme.Colors.acLeaf, padding: CGFloat = 16) {
        self.title = title
        self.value = value
        self.icon = icon
        self.iconColor = iconColor
        self.padding = padding
    }

    public var body: some View {
        VStack(spacing: icon != nil ? 8 : 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(iconColor)
            }
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.acTextDark)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(title)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.acTextMuted)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .acCardStyle(padding: padding)
    }
}
