import SwiftUI

struct QuestProgressRibbon: View {
    let quest: DailyQuest
    let currentStopNumber: Int
    let totalStopsInQuest: Int
    let currentStopName: String
    let routeProgress: Double

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(Theme.Typography.label)
                    Text(quest.title.uppercased())
                        .font(Theme.Typography.label)
                        .kerning(1.0)
                }
                .foregroundColor(Theme.Colors.acTextDark.opacity(0.6))

                Spacer()

                Text("STOP \(currentStopNumber) OF \(totalStopsInQuest)")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.acLeaf)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Theme.Colors.acLeaf.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Theme.Colors.acBorder.opacity(0.2))
                        .frame(height: 6)

                    let total = Double(totalStopsInQuest)
                    let current = Double(currentStopNumber)
                    let legProgress = routeProgress / total
                    let overallProgress = (max(0, current - 1) / total) + legProgress

                    Capsule()
                        .fill(Theme.Colors.acLeaf)
                        .frame(width: geo.size.width * min(1.0, overallProgress), height: 6)
                }
            }
            .frame(height: 6)
            .padding(.horizontal, 16)

            if !currentStopName.isEmpty {
                Text("Next: \(currentStopName)")
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 12)
        .background(Theme.Colors.acBorder.opacity(0.08))
        Divider().background(Theme.Colors.acBorder.opacity(0.3))
    }
}
