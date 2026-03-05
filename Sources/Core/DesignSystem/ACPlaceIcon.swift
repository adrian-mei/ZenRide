import SwiftUI
import UIKit

// MARK: - ACPlaceIcon

public struct ACPlaceIcon: View {
    let icon: String
    let color: Color
    let title: String
    
    public init(icon: String, color: Color, title: String) {
        self.icon = icon
        self.color = color
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
                    .frame(width: 62, height: 62)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.Colors.acBorder, lineWidth: 2)
                    )
                    .shadow(color: color.opacity(0.45), radius: 0, x: 0, y: 4)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acTextDark)
        }
        .bunnyPaw()
    }
}
