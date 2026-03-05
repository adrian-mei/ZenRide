import SwiftUI

// MARK: - ACDangerButton

/// Coral-outline capsule button for destructive / end actions.
public struct ACDangerButton: View {
    let title: String
    var icon: String?
    var isFullWidth: Bool = true
    let action: () -> Void

    public init(title: String, icon: String? = nil, isFullWidth: Bool = true, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isFullWidth = isFullWidth
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon).font(Theme.Typography.button)
                }
                Text(title).font(Theme.Typography.button)
            }
            .foregroundColor(Theme.Colors.acCoral)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.vertical, 12)
            .padding(.horizontal, isFullWidth ? 0 : 24)
            .background(Theme.Colors.acCream)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.Colors.acCoral, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}
