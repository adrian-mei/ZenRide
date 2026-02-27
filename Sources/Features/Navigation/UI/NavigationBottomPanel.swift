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
        let traveled = locationProvider.isSimulating ? locationProvider.distanceTraveledInSimulationMeters : routingService.distanceTraveledMeters
        return min(1, traveled / Double(routingService.routeDistanceMeters))
    }

    var remainingTimeSeconds: Int {
        let remaining = Double(routingService.routeTimeSeconds) * (1.0 - routeProgress)
        return max(0, Int(remaining))
    }

    var remainingDistanceMeters: Double {
        let traveled = locationProvider.isSimulating ? locationProvider.distanceTraveledInSimulationMeters : routingService.distanceTraveledMeters
        return max(0, Double(routingService.routeDistanceMeters) - traveled)
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

    var isCruiseMode: Bool {
        routingService.activeRoute.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Theme.Colors.acWood.opacity(0.3))
                .frame(width: 36, height: 6)
                .padding(.top, 12)
                .padding(.bottom, 20)

            if isCruiseMode {
                HStack(spacing: 0) {
                    metricsColumn(value: "Cruising", label: "mode", fontSize: 32)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            } else if isArriving {
                Text("Almost there!")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acLeaf)
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
                Text(isCruiseMode ? "End Drive" : "End Route")
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Colors.acCoral)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 32)
                    .background(Theme.Colors.acCream)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.Colors.acCoral, lineWidth: 2))
            }
            .padding(.bottom, 32)
        }
        .background(Theme.Colors.acField)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: isArriving) { arriving in
            if !isCruiseMode && arriving {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    arrivingPulse = true
                }
            } else {
                arrivingPulse = false
            }
        }
    }

    private func metricsColumn(value: String, label: String, fontSize: CGFloat = 40) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundColor(Theme.Colors.acTextDark)
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
        }
        .frame(maxWidth: .infinity)
    }

    private var columnDivider: some View {
        Rectangle()
            .fill(Theme.Colors.acBorder.opacity(0.4))
            .frame(width: 2, height: 44)
    }
}
