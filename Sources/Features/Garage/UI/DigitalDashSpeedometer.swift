import SwiftUI

struct DigitalDashSpeedometer: View {
    @ObservedObject var bunnyPolice: BunnyPolice
    @ObservedObject var locationProvider: LocationProvider

    var speedLimit: Double { Double(bunnyPolice.nearestCamera?.speed_limit_mph ?? 45) }

    var currentSpeedColor: Color {
        let s = locationProvider.currentSpeedMPH
        if s > speedLimit + 10 { return Theme.Colors.acCoral }
        if s > speedLimit      { return Theme.Colors.acGold }
        return Theme.Colors.acLeaf
    }

    var speedRatio: Double { min(max(locationProvider.currentSpeedMPH / 120.0, 0.0), 1.0) }

    var speedDelta: Int? {
        if bunnyPolice.currentZone == .safe { return nil }
        let s = locationProvider.currentSpeedMPH
        let delta = Int(s) - Int(speedLimit)
        return delta == 0 ? nil : delta
    }

    var isDanger: Bool {
        bunnyPolice.currentZone == .danger
    }

    var body: some View {
        ZStack {
            // Background Card
            Circle()
                .fill(Theme.Colors.acCream)
                .frame(width: 140, height: 140)
                .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 4))
                .shadow(color: Theme.Colors.acBorder.opacity(0.4), radius: 0, x: 0, y: 6)

            // Speed gauge arc
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(Theme.Colors.acBorder.opacity(0.3), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(180))
                .frame(width: 110, height: 110)

            Circle()
                .trim(from: 0.5, to: 0.5 + (0.5 * speedRatio))
                .stroke(currentSpeedColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(180))
                .frame(width: 110, height: 110)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: speedRatio)

            VStack(spacing: 2) {
                // Current Speed
                Text("\(Int(locationProvider.currentSpeedMPH))")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .contentTransition(.numericText())
                    .offset(y: 8)

                Text("mph")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .offset(y: 4)

                // Speed Limit Sign
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Theme.Colors.acCream)
                        .frame(width: 36, height: 36)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isDanger ? Theme.Colors.acCoral : Theme.Colors.acBorder, lineWidth: 2))
                    
                    VStack(spacing: 0) {
                        Text("LIMIT")
                            .font(.system(size: 6, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)
                        Text("\(Int(speedLimit))")
                            .font(.system(size: 14, weight: .black, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextDark)
                    }
                }
                .offset(y: 12)
                .scaleEffect(isDanger ? 1.1 : 1.0)
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isDanger)
            }
        }
        .frame(width: 140, height: 140)
    }
}
