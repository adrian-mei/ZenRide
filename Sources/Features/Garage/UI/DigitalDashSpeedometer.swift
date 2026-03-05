import SwiftUI

struct DigitalDashSpeedometer: View {
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider

    var speedLimit: Double { Double(bunnyPolice.nearestCamera?.speed_limit_mph ?? 30) }

    var currentSpeedColor: Color {
        let s = locationProvider.currentSpeedMPH
        if s > speedLimit + 10 { return Color.red }
        if s > speedLimit { return Color.orange }
        return Color.black
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
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(isDanger ? Color.red : Color.gray.opacity(0.3), lineWidth: isDanger ? 3 : 1)
        )
        .shadow(color: isDanger ? Color.red.opacity(pulse ? 0.6 : 0.0) : Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
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
                .fill(Color.white)

            VStack(spacing: 0) {
                Text("SPEED")
                    .font(.system(size: 8, weight: .bold, design: .default))
                    .foregroundColor(.black)
                Text("LIMIT")
                    .font(.system(size: 8, weight: .bold, design: .default))
                    .foregroundColor(.black)
                    .padding(.bottom, 2)
                Text("\(Int(speedLimit))")
                    .font(.system(size: 24, weight: .black, design: .default))
                    .foregroundColor(.black)
            }
        }
        .frame(width: 50, height: 60)
        .border(Color.black, width: 2)
        .padding(4)
        .background(Color.white)
        .overlay(
            VStack {
                if isDanger {
                    Text("OVERSPEED")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
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
                .font(.system(size: 32, weight: .black, design: .default))
                .foregroundColor(currentSpeedColor)
                .contentTransition(.numericText())

            Text("mph")
                .font(.system(size: 12, weight: .bold, design: .default))
                .foregroundColor(Color.gray)
        }
        .frame(width: 60, height: 60)
        .background(Color.white)
    }

    private var compassView: some View {
        VStack(spacing: 4) {
            Image(systemName: "location.north.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.blue)
                .rotationEffect(.degrees(max(0, locationProvider.currentLocation?.course ?? 0)))

            Text(compassDirection)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.black)
        }
        .frame(width: 40, height: 60)
        .background(Color.white)
    }

    private var ecoView: some View {
        VStack(spacing: 4) {
            Image(systemName: "leaf.fill")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(ecoColor)

            Text("\(Int(locationProvider.ecoScore))")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.black)
        }
        .frame(width: 40, height: 60)
        .background(Color.white)
    }

    private var ecoColor: Color {
        let score = locationProvider.ecoScore
        if score > 80 { return Color(red: 0.35, green: 0.68, blue: 0.43) } // acLeaf
        if score > 50 { return Color.orange }
        return Color.red
    }
}
