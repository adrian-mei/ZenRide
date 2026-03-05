import SwiftUI

// MARK: - ACStatBar

/// Horizontal stat bar with label and colored fill.
public struct ACStatBar: View {
    let label: String
    let value: Double
    let color: Color

    public init(label: String, value: Double, color: Color) {
        self.label = label
        self.value = value
        self.color = color
    }

    public var body: some View {
        HStack {
            Text(label)
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.acTextMuted)
                .frame(width: 60, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.acBorder.opacity(0.3))
                        .frame(height: 8)

                    Capsule()
                        .fill(color)
                        .frame(width: max(0, min(geo.size.width * (value / 10.0), geo.size.width)), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}
