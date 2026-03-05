import SwiftUI
import UIKit

// MARK: - ACSquareActionButton

public struct ACSquareActionButton: View {
    let icon: String
    let title: String
    var color: Color = Theme.Colors.acWood
    var action: () -> Void = {}
    
    public init(icon: String, title: String, color: Color = Theme.Colors.acWood, action: @escaping () -> Void = {}) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(color)

                Text(title)
                    .font(.system(size: 13, weight: .black, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextDark)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(ACButtonStyle(variant: .largeSecondary))
    }
}
