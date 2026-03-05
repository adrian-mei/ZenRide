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
                        .font(.system(size: 10, weight: .bold))
                    Text(quest.title.uppercased())
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .kerning(1.0)
                }
                .foregroundColor(Color.white.opacity(0.6))

                Spacer()

                Text("STOP \(currentStopNumber) OF \(totalStopsInQuest)")
                    .font(.system(size: 10, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "4CD964"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(hex: "4CD964").opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 16)

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    let total = Double(totalStopsInQuest)
                    let current = Double(currentStopNumber)
                    let legProgress = routeProgress / total
                    let overallProgress = (max(0, current - 1) / total) + legProgress

                    Capsule()
                        .fill(Color(hex: "4CD964"))
                        .frame(width: geo.size.width * min(1.0, overallProgress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)

            if !currentStopName.isEmpty {
                Text("Next: \(currentStopName)")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.05))
        Divider().background(Color.white.opacity(0.15))
    }
}
