import SwiftUI
import UIKit

// MARK: - ACMapRoundButton

/// Circular map-overlay button with active/inactive state.
public struct ACMapRoundButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    public init(icon: String, label: String, isActive: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.action = action
    }

    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            action()
        }) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .bold))
                .frame(width: 48, height: 48)
        }
        .buttonStyle(ACMapRoundButtonStyle(isActive: isActive))
        .accessibilityLabel(label)
        .padding(.bottom, 6)
    }
}

// MARK: - ACMapRoundButtonStyle

public struct ACMapRoundButtonStyle: ButtonStyle {
    public var isActive: Bool

    public init(isActive: Bool) {
        self.isActive = isActive
    }

    public func makeBody(configuration: Configuration) -> some View {
        let isPressed = configuration.isPressed
        let scale: CGFloat = isPressed ? 0.90 : 1.0

        ZStack {
            // Drop shadow
            Circle()
                .fill(Theme.Colors.acBorder.opacity(0.8))
                .frame(width: 56, height: 56)
                .offset(y: 4)

            // Outer thick border
            Circle()
                .fill(isActive ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.8))
                .frame(width: 56, height: 56)

            // Inner face
            ZStack {
                if isActive {
                    Circle().fill(Theme.Colors.acLeaf.opacity(0.15))
                } else {
                    Circle().fill(.ultraThinMaterial).background(Circle().fill(Theme.Colors.acCream.opacity(0.8)))
                }
            }
            .frame(width: 48, height: 48)

            // Icon content
            configuration.label
                .foregroundColor(isActive ? Theme.Colors.acLeaf : Theme.Colors.acWood)
        }
        .scaleEffect(scale)
        .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isPressed)
    }
}
