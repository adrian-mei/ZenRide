import SwiftUI

// MARK: - ACMetricsColumn

/// Single-column metric display used in navigation HUD (value + unit label).
public struct ACMetricsColumn: View {
    let value: String
    let label: String
    var fontSize: CGFloat = 40

    public init(value: String, label: String, fontSize: CGFloat = 40) {
        self.value = value
        self.label = label
        self.fontSize = fontSize
    }

    public var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundColor(Theme.Colors.acTextDark)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
        }
        .frame(maxWidth: .infinity)
    }
}
