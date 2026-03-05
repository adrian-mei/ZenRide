import SwiftUI

// MARK: - ACPillButton

/// Neutral pill button (Find a Place, etc.).
public struct ACPillButton: View {
    let title: String
    var icon: String?
    var color: Color = Theme.Colors.acTextDark
    var isFullWidth: Bool = false
    let action: () -> Void

    public init(title: String, icon: String? = nil, color: Color = Theme.Colors.acTextDark, isFullWidth: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.color = color
        self.isFullWidth = isFullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                }
                Text(title).font(Theme.Typography.button)
            }
            .foregroundColor(color)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, isFullWidth ? 0 : 20)
            .background(Theme.Colors.acCream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.acBorder, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
