import SwiftUI
import UIKit

/// ZenMap (Animal Crossing / Camp) Theme Engine
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

        // UI State Colors
        public static let acAction = Color(hex: "007AFF")
        public static let acSuccess = Color(hex: "4CD964")
        public static let acError = Color(hex: "FF3B30")
        public static let acCharcoal = Color(hex: "1C1C1E")

        // Deep wood color for text on light backgrounds
        public static let acTextDark = Color(hex: "5C4A1E")
        public static let acTextMuted = Color(hex: "8B6914")
    }

    // MARK: - Typography
    public struct Typography {
        /// Heavy, rounded title font mimicking Quicksand/Nunito black
        public static let display = Font.system(size: 64, weight: .black, design: .rounded)
        public static let largeTitle = Font.system(size: 34, weight: .black, design: .rounded)
        public static let title = Font.system(size: 28, weight: .black, design: .rounded)
        public static let title2 = Font.system(size: 24, weight: .black, design: .rounded)
        public static let headline = Font.system(size: 20, weight: .bold, design: .rounded)
        public static let title3 = Font.system(size: 18, weight: .bold, design: .rounded)
        public static let body = Font.system(size: 16, weight: .medium, design: .rounded)
        public static let button = Font.system(size: 14, weight: .black, design: .rounded)
        public static let caption = Font.system(size: 12, weight: .bold, design: .rounded)
        public static let label = Font.system(size: 10, weight: .black, design: .rounded)
    }
}
