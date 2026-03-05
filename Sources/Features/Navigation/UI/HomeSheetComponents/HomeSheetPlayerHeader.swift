import SwiftUI

struct HomeSheetPlayerHeader: View {
    let level: Int
    let xp: Int
    let progress: Double
    let icon: String
    let colorHex: String

    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 50, height: 50)
                Image(systemName: icon)
                    .font(Theme.Typography.title2)
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Level \(level)")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: level)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Colors.acBorder.opacity(0.3))
                        Capsule()
                            .fill(Theme.Colors.acLeaf)
                            .frame(width: geo.size.width * progress)
                            .animation(.spring(response: 0.5, dampingFraction: 0.75), value: progress)
                    }
                }
                .frame(height: 8)
            }

            Spacer()

            Text("\(xp) XP")
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acLeaf)
                .contentTransition(.numericText())
                .animation(.spring(response: 0.4, dampingFraction: 0.7), value: xp)
        }
        .padding(.horizontal)
    }
}
