import SwiftUI

// MARK: - ACBadge

/// Capsule badge with optional leading icon.
public struct ACBadge: View {
    let text: String
    var textColor: Color = Theme.Colors.acCream
    var backgroundColor: Color = Theme.Colors.acLeaf
    var icon: String?

    public init(text: String, textColor: Color = Theme.Colors.acCream, backgroundColor: Color = Theme.Colors.acLeaf, icon: String? = nil) {
        self.text = text
        self.textColor = textColor
        self.backgroundColor = backgroundColor
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 10))
            }
            Text(text)
                .font(Theme.Typography.label)
        }
        .foregroundColor(textColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(backgroundColor)
        .clipShape(Capsule())
    }
}
