import SwiftUI

struct StatRow: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
                .frame(width: 54, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.acField)
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * (value / 10.0))
                        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: value)
                }
            }
            .frame(height: 10)

            Text(String(format: "%.0f", value))
                .font(.system(size: 11, weight: .black, design: .rounded))
                .foregroundColor(Theme.Colors.acTextDark)
                .frame(width: 18, alignment: .trailing)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: value)
        }
    }
}
