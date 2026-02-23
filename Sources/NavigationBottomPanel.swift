import SwiftUI

// Static formatter: created once, never again
private let arrivalFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

struct NavigationBottomPanel: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var owlPolice: OwlPolice
    var onEnd: () -> Void

    @State private var arrivingPulse = false

    var remainingTimeSeconds: Int {
        let progress = owlPolice.distanceTraveledInSimulationMeters / Double(max(1, routingService.routeDistanceMeters))
        let remaining = Double(routingService.routeTimeSeconds) * (1.0 - progress)
        return max(0, Int(remaining))
    }

    var remainingDistanceMeters: Double {
        max(0, Double(routingService.routeDistanceMeters) - owlPolice.distanceTraveledInSimulationMeters)
    }

    var isArriving: Bool { remainingTimeSeconds <= 10 }

    var arrivalTime: String {
        arrivalFormatter.string(from: Date().addingTimeInterval(TimeInterval(remainingTimeSeconds)))
    }

    var formattedDistance: String {
        let miles = remainingDistanceMeters / 1609.34
        if remainingDistanceMeters < 1609 {
            return "\(Int(remainingDistanceMeters))m"
        }
        return String(format: "%.1f mi", miles)
    }

    var formattedTime: String {
        if isArriving { return "Arriving" }
        if remainingTimeSeconds < 60 { return "< 1 min" }
        return "\(remainingTimeSeconds / 60) min"
    }

    var etaColor: Color {
        isArriving ? .green : Color(red: 0.1, green: 0.8, blue: 0.3)
    }

    var body: some View {
        VStack(spacing: 12) {
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 12)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(isArriving ? "You're here" : arrivalTime)
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundColor(etaColor)
                            .opacity(isArriving ? (arrivingPulse ? 1.0 : 0.5) : 1.0)
                            .contentTransition(.numericText())
                        if !isArriving {
                            Text("ETA")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundColor(.secondary)
                        }
                    }

                    HStack(spacing: 6) {
                        Text(formattedTime)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                        Text("•")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(formattedDistance)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                            .contentTransition(.numericText())
                    }
                }

                Spacer()

                Button(action: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onEnd()
                }) {
                    Text("End")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 56)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("End Route")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: isArriving) { arriving in
            if arriving {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    arrivingPulse = true
                }
            } else {
                arrivingPulse = false
            }
        }
    }
}
