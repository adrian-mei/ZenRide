import SwiftUI

struct DigitalDashSpeedometer: View {
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider

    var speedLimit: Double { Double(bunnyPolice.nearestCamera?.speed_limit_mph ?? 30) }

    var currentSpeedColor: Color {
        let s = locationProvider.currentSpeedMPH
        if s > speedLimit + 10 { return Theme.Colors.acError }
        if s > speedLimit { return Theme.Colors.acGold }
        return Theme.Colors.acTextDark
    }

    var isDanger: Bool {
        bunnyPolice.currentZone == .danger || locationProvider.currentSpeedMPH > speedLimit + 10
    }

    var compassDirection: String {
        let course = locationProvider.currentLocation?.course ?? -1
        if course < 0 { return "--" }
        let directions = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((course + 22.5) / 45.0) % 8
        return directions[index]
    }

    @State private var pulse: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            speedLimitView

            currentSpeedView

            Divider().frame(height: 40)

            compassView

            Divider().frame(height: 40)

            ecoView
        }
        .background(Theme.Colors.acCream)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDanger ? Theme.Colors.acError : Theme.Colors.acBorder.opacity(0.3), lineWidth: isDanger ? 3 : 1)
        )
        .shadow(color: isDanger ? Theme.Colors.acError.opacity(pulse ? 0.6 : 0.0) : Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: pulse)
        .onChange(of: isDanger) { _, danger in
            if danger {
                pulse = true
            } else {
                pulse = false
            }
        }
    }

    private var speedLimitView: some View {
        ZStack {
            Rectangle()
                .fill(Theme.Colors.acCream)

            VStack(spacing: 0) {
                Text("SPEED")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.acTextDark)
                Text("LIMIT")
                    .font(Theme.Typography.label)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .padding(.bottom, 2)
                Text("\(Int(speedLimit))")
                    .font(Theme.Typography.title2)
                    .foregroundColor(Theme.Colors.acTextDark)
            }
        }
        .frame(width: 50, height: 60)
        .border(Theme.Colors.acBorder, width: 2)
        .padding(4)
        .background(Theme.Colors.acCream)
        .overlay(
            VStack {
                if isDanger {
                    Text("OVERSPEED")
                        .font(Theme.Typography.label)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.acError)
                        .clipShape(Capsule())
                        .offset(y: -12)
                        .opacity(pulse ? 1.0 : 0.4)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: isDanger),
            alignment: .top
        )
    }

    private var currentSpeedView: some View {
        VStack(spacing: -4) {
            Text("\(Int(locationProvider.currentSpeedMPH))")
                .font(Theme.Typography.largeTitle)
                .foregroundColor(currentSpeedColor)
                .contentTransition(.numericText())

            Text("mph")
                .font(Theme.Typography.caption)
                .foregroundColor(Theme.Colors.acTextMuted)
        }
        .frame(width: 60, height: 60)
        .background(Theme.Colors.acCream)
    }

    private var compassView: some View {
        VStack(spacing: 4) {
            Image(systemName: "location.north.fill")
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acAction)
                .rotationEffect(.degrees(max(0, locationProvider.currentLocation?.course ?? 0)))

            Text(compassDirection)
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acTextDark)
        }
        .frame(width: 40, height: 60)
        .background(Theme.Colors.acCream)
    }

    private var ecoView: some View {
        VStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(Theme.Typography.button)
                .foregroundColor(ecoColor)

            Text("\(Int(locationProvider.ecoScore))")
                .font(Theme.Typography.label)
                .foregroundColor(Theme.Colors.acTextDark)
        }
        .frame(width: 40, height: 60)
        .background(Theme.Colors.acCream)
    }

    private var ecoColor: Color {
        let score = locationProvider.ecoScore
        if score > 80 { return Theme.Colors.acSuccess }
        if score > 50 { return Theme.Colors.acGold }
        return Theme.Colors.acError
    }
}
