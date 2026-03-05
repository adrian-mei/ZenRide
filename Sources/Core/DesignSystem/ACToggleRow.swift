import SwiftUI

// MARK: - ACToggleRow

/// Full-width toggle row with an icon and green tint.
public struct ACToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    public init(title: String, icon: String, isOn: Binding<Bool>) {
        self.title = title
        self.icon = icon
        self._isOn = isOn
    }

    public var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Theme.Colors.acWood)
                    .frame(width: 24)
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark)
            }
        }
        .tint(Theme.Colors.acLeaf)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
