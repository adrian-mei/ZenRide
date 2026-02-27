import SwiftUI

/// FashodaMap (Animal Crossing / Camp) Theme Engine
/// Ports the exact CSS palette from the `fashoda` web app ecosystem.
public struct Theme {
    
    // MARK: - Colors (Camping / Animal Crossing Palette)
    public struct Colors {
        public static let acLeaf = Color(hex: "5BAD6F")
        public static let acMint = Color(hex: "A8D8A8")
        public static let acSky = Color(hex: "87CEEB")
        public static let acCream = Color(hex: "FFF9E6")
        public static let acField = Color(hex: "F5E6C8")
        public static let acBorder = Color(hex: "D4B483")
        public static let acGold = Color(hex: "F4C430")
        public static let acCoral = Color(hex: "FF8C7A")
        public static let acWood = Color(hex: "C68642")
        public static let acGrass = Color(hex: "4CAF50")
        public static let acLavender = Color(hex: "C3B1E1")
        
        // Deep wood color for text on light backgrounds
        public static let acTextDark = Color(hex: "5C4A1E")
        public static let acTextMuted = Color(hex: "8B6914")
    }
    
    // MARK: - Typography
    public struct Typography {
        /// Heavy, rounded title font mimicking Quicksand/Nunito black
        public static let title = Font.system(size: 28, weight: .black, design: .rounded)
        public static let headline = Font.system(size: 20, weight: .bold, design: .rounded)
        public static let body = Font.system(size: 16, weight: .medium, design: .rounded)
        public static let button = Font.system(size: 14, weight: .black, design: .rounded)
    }
}

// MARK: - Hex Color Support
public extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Modifiers (ACCard)

public struct ACCardModifier: ViewModifier {
    var padding: CGFloat = 16
    var isInteractive: Bool = false
    @State private var isPressed: Bool = false

    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.Colors.acCream)
            // Wood border
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Colors.acBorder.opacity(0.8), lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            // 3D Drop Shadow effect that "presses" down
            .shadow(color: Theme.Colors.acBorder, radius: 0, x: 0, y: isPressed ? 0 : 6)
            // Slight vertical shift to complete the physical press illusion
            .offset(y: isPressed ? 6 : 0)
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard isInteractive else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = true
                        }
                    }
                    .onEnded { _ in
                        guard isInteractive else { return }
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isPressed = false
                        }
                    }
            )
    }
}

extension View {
    /// Applies the Animal Crossing card style (cream bg, wood border, chunky shadow)
    func acCardStyle(padding: CGFloat = 16, interactive: Bool = false) -> some View {
        self.modifier(ACCardModifier(padding: padding, isInteractive: interactive))
    }
}

// MARK: - ACButton Styles

public struct ACButtonStyle: ButtonStyle {
    public enum Variant {
        case primary // Green
        case secondary // Field / Cream
    }
    
    var variant: Variant
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Typography.button)
            .padding(.horizontal, 24)
            .frame(minHeight: 48)
            .background(backgroundColor(isPressed: configuration.isPressed))
            .foregroundColor(textColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(borderColor, lineWidth: 2)
            )
            .shadow(color: shadowColor, radius: 0, x: 0, y: configuration.isPressed ? 0 : 6)
            .offset(y: configuration.isPressed ? 6 : 0)
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
    
    private func backgroundColor(isPressed: Bool) -> Color {
        switch variant {
        case .primary:
            return isPressed ? Theme.Colors.acLeaf.opacity(0.8) : Theme.Colors.acLeaf
        case .secondary:
            return isPressed ? Theme.Colors.acCream : Theme.Colors.acField
        }
    }
    
    private var textColor: Color {
        switch variant {
        case .primary: return .white
        case .secondary: return Theme.Colors.acTextDark
        }
    }
    
    private var borderColor: Color {
        switch variant {
        case .primary: return Color(hex: "388E3C")
        case .secondary: return Theme.Colors.acBorder
        }
    }
    
    private var shadowColor: Color {
        switch variant {
        case .primary: return Color(hex: "388E3C")
        case .secondary: return Theme.Colors.acBorder
        }
    }
}
