import SwiftUI

// MARK: - ACSectionHeader

/// Labelled section header with an icon, matching the Animal Crossing wood-tone style.
public struct ACSectionHeader: View {
    let title: String
    let icon: String
    var color: Color = Theme.Colors.acWood
    
    public init(title: String, icon: String, color: Color = Theme.Colors.acWood) {
        self.title = title
        self.icon = icon
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.system(size: 12, weight: .black, design: .rounded))
                .foregroundColor(color)
                .kerning(1.5)
        }
    }
}
