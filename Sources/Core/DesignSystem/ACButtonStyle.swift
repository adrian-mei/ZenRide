import SwiftUI
import UIKit

// MARK: - ACButtonStyle

public struct ACButtonStyle: ButtonStyle {
    public enum Variant {
        case primary // Green
        case secondary // Field / Cream
        case largePrimary // Green, cornerRadius 28, label provides own layout
        case largeSecondary // Field/tan, cornerRadius 28, label provides own layout
    }

    var variant: Variant
    
    public init(variant: Variant) {
        self.variant = variant
    }

    public func makeBody(configuration: Configuration) -> some View {
        let liftY: CGFloat = configuration.isPressed ? 0 : 6
        let radius: CGFloat = isLarge ? 28 : 22

        ZStack {
            // Bottom depth slab (stationary — creates the chunky 3D base)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(shadowColor)

            // Top face + Label
            Group {
                if isLarge {
                    configuration.label
                } else {
                    configuration.label
                        .font(Theme.Typography.button)
                        .foregroundColor(textColor)
                        .padding(.horizontal, 24)
                }
            }
            .frame(maxWidth: isLarge ? .infinity : nil)
            .frame(minHeight: isLarge ? 84 : 56)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(backgroundColor(isPressed: configuration.isPressed))
                    .overlay(
                        RoundedRectangle(cornerRadius: radius, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1.5)
                    )
            )
            .offset(y: -liftY)
        }
        .fixedSize(horizontal: false, vertical: true)
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
        .rotationEffect(.degrees(configuration.isPressed ? -1 : 0))
        .animation(.spring(response: 0.25, dampingFraction: 0.6), value: configuration.isPressed)
    }

    private var isLarge: Bool {
        variant == .largePrimary || variant == .largeSecondary
    }

    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary, .largePrimary:
            return isPressed ? Theme.Colors.acLeaf.opacity(0.8) : Theme.Colors.acLeaf
        case .secondary, .largeSecondary:
            return isPressed ? Theme.Colors.acCream : Theme.Colors.acField
        }
    }

    private var textColor: Color {
        switch variant {
        case .primary, .largePrimary: return .white
        case .secondary, .largeSecondary: return Theme.Colors.acTextDark
        }
    }

    private var borderColor: Color {
        switch variant {
        case .primary, .largePrimary: return Color(hex: "388E3C")
        case .secondary, .largeSecondary: return Theme.Colors.acBorder
        }
    }

    private var shadowColor: Color {
        switch variant {
        case .primary, .largePrimary: return Color(hex: "388E3C")
        case .secondary, .largeSecondary: return Theme.Colors.acBorder
        }
    }
}
