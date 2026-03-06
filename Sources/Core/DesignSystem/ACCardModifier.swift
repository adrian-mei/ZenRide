import SwiftUI
import UIKit

// MARK: - Modifiers (ACCard)

public struct ACTextureOverlay: View {
    public init() {}
    
    public var body: some View {
        GeometryReader { geo in
            Path { path in
                let step: CGFloat = 12
                for x in stride(from: 0, through: geo.size.width, by: step) {
                    for y in stride(from: 0, through: geo.size.height, by: step) {
                        path.addEllipse(in: CGRect(x: x, y: y, width: 1.5, height: 1.5))
                    }
                }
            }
            .fill(Theme.Colors.acBorder.opacity(0.15))
        }
    }
}

public struct ACCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var isInteractive: Bool = false
    var hasTexture: Bool = true
    @State private var isPressed: Bool = false

    public init(padding: CGFloat = 16, isInteractive: Bool = false, hasTexture: Bool = true) {
        self.padding = padding
        self.isInteractive = isInteractive
        self.hasTexture = hasTexture
    }

    @ViewBuilder
    public func body(content: Content) -> some View {
        let base = content
            .padding(padding)
            .background(
                ZStack {
                    Theme.Colors.acCream
                    if hasTexture {
                        ACTextureOverlay()
                    }
                }
            )
            // Wood border
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.Colors.acBorder.opacity(0.8), lineWidth: 2.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            // Secondary soft shadow for ambient occlusion/depth
            .shadow(color: Color.black.opacity(0.05), radius: isPressed ? 2 : 10, x: 0, y: isPressed ? 2 : 5)
            // 3D Drop Shadow effect that "presses" down
            .shadow(color: Theme.Colors.acBorder.opacity(0.8), radius: 0, x: 0, y: isPressed ? 0 : 8)
            // Slight vertical shift to complete the physical press illusion
            .offset(y: isPressed ? 8 : 0)

        if isInteractive {
            base.simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = false
                        }
                    }
            )
        } else {
            base
        }
    }
}

public extension View {
    /// Applies the Animal Crossing card style (textured cream bg, wood border, chunky 8pt shadow)
    func acCardStyle(padding: CGFloat = 16, interactive: Bool = false, hasTexture: Bool = true) -> some View {
        self.modifier(ACCardModifier(padding: padding, isInteractive: interactive, hasTexture: hasTexture))
    }

    /// Bouncy, slightly rotating spring animation for that squishy AC feel.
    func acWobble(isPressed: Bool) -> some View {
        self.scaleEffect(isPressed ? 0.94 : 1.0)
            .rotationEffect(.degrees(isPressed ? -2 : 0))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
    }
}
