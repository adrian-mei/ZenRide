import SwiftUI

public struct ACGlassModifier: ViewModifier {
    var cornerRadius: CGFloat

    public func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

public extension View {
    func acGlass(cornerRadius: CGFloat = 24) -> some View {
        self.modifier(ACGlassModifier(cornerRadius: cornerRadius))
    }
}
