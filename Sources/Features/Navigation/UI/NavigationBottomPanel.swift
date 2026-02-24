import SwiftUI

private let arrivalFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm"
    return f
}()

struct NavigationBottomPanel: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider
    var onEnd: () -> Void

    @State private var arrivingPulse = false

    // MARK: - Computed

    var routeProgress: Double {
        guard routingService.routeDistanceMeters > 0 else { return 0 }
        return min(1, locationProvider.distanceTraveledInSimulationMeters / Double(routingService.routeDistanceMeters))
    }

    var remainingTimeSeconds: Int {
        let remaining = Double(routingService.routeTimeSeconds) * (1.0 - routeProgress)
        return max(0, Int(remaining))
    }

    var remainingDistanceMeters: Double {
        max(0, Double(routingService.routeDistanceMeters) - locationProvider.distanceTraveledInSimulationMeters)
    }

    var isArriving: Bool { remainingDistanceMeters < 320 }

    var arrivalTime: String {
        arrivalFormatter.string(from: Date().addingTimeInterval(TimeInterval(remainingTimeSeconds)))
    }

    var remainingMinutes: Int { max(0, remainingTimeSeconds / 60) }

    var distanceValue: String {
        remainingDistanceMeters < 1609
            ? "\(Int(remainingDistanceMeters))"
            : String(format: "%.1f", remainingDistanceMeters / 1609.34)
    }

    var distanceUnit: String {
        remainingDistanceMeters < 1609 ? "m" : "mi"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.25))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            if isArriving {
                Text("Arriving")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.green)
                    .opacity(arrivingPulse ? 1.0 : 0.5)
                    .padding(.vertical, 24)
            } else {
                // 3-column layout
                HStack(spacing: 0) {
                    metricsColumn(value: arrivalTime, label: "arrival")
                    columnDivider
                    metricsColumn(value: "\(remainingMinutes)", label: "min")
                    columnDivider
                    metricsColumn(value: distanceValue, label: distanceUnit)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            Button(action: onEnd) {
                Text("End Route")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.red.opacity(0.75))
            }
            .padding(.bottom, 28)
        }
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.thinMaterial)
                .environment(\.colorScheme, .dark)
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

    private func metricsColumn(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 52, weight: .bold))
                .foregroundColor(.white)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.55))
        }
        .frame(maxWidth: .infinity)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.12))
            .frame(width: 1, height: 44)
    }
}
