import SwiftUI
import UIKit

// MARK: - ACBunnyPawEffect

/// Scale-bounce + soft haptic on tap — opt-in Bunny Police theme interaction.
public struct ACBunnyPawEffect: ViewModifier {
    @State private var popped = false

    public init() {}

    public func body(content: Content) -> some View {
        content
            .scaleEffect(popped ? 0.88 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: popped)
            .onTapGesture {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                popped = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { popped = false }
            }
    }
}

public extension View {
    func bunnyPaw() -> some View { modifier(ACBunnyPawEffect()) }
}
