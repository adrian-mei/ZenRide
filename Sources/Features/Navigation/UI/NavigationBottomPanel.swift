import SwiftUI

private let arrivalFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm"
    return f
}()

struct NavigationBottomPanel: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var multiplayerService: MultiplayerService

    var onEnd: () -> Void
    var onSetDestination: (() -> Void)? = nil
    var departureTime: Date? = nil
    var cruiseOdometerMiles: Double = 0

    @State private var arrivingPulse = false
    @State private var now: Date = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed

    var routeProgress: Double {
        guard routingService.routeDistanceMeters > 0 else { return 0 }
        let traveled = locationProvider.isSimulating
            ? locationProvider.distanceTraveledInSimulationMeters
            : routingService.distanceTraveledMeters
        return min(1, traveled / Double(routingService.routeDistanceMeters))
    }

    var remainingTimeSeconds: Int {
        let remaining = Double(routingService.routeTimeSeconds) * (1.0 - routeProgress)
        return max(0, Int(remaining))
    }

    var remainingDistanceMeters: Double {
        let traveled = locationProvider.isSimulating
            ? locationProvider.distanceTraveledInSimulationMeters
            : routingService.distanceTraveledMeters
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

    // Cruise-specific stats
    var elapsedFormatted: String {
        guard let start = departureTime else { return "0:00" }
        let secs = max(0, Int(now.timeIntervalSince(start)))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    var cruiseDistanceFormatted: String {
        cruiseOdometerMiles < 0.1
            ? String(format: "%.0f ft", cruiseOdometerMiles * 5280)
            : String(format: "%.1f", cruiseOdometerMiles)
    }

    var cruiseDistanceUnit: String {
        cruiseOdometerMiles < 0.1 ? "ft" : "mi"
    }

    var currentSpeedString: String {
        String(format: "%.0f", max(0, locationProvider.currentSpeedMPH))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Theme.Colors.acWood.opacity(0.3))
                .frame(width: 36, height: 6)
                .padding(.top, 12)
                .padding(.bottom, 16)

            if isCruiseMode {
                cruiseModeContent
            } else if isArriving {
                Text("Almost there!")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acLeaf)
                    .opacity(arrivingPulse ? 1.0 : 0.5)
                    .padding(.vertical, 24)
                ACDangerButton(title: "End Route", isFullWidth: false, action: onEnd)
                    .padding(.bottom, 32)
            } else {
                // 3-column route progress layout
                HStack(spacing: 0) {
                    ACMetricsColumn(value: arrivalTime, label: "arrival")
                    columnDivider
                    ACMetricsColumn(value: "\(remainingMinutes)", label: "min")
                    columnDivider
                    ACMetricsColumn(value: distanceValue, label: distanceUnit)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                ACDangerButton(title: "End Route", isFullWidth: false, action: onEnd)
                    .padding(.bottom, 32)
            }
        }
        .background(Theme.Colors.acField)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .ignoresSafeArea(edges: .bottom)
        .onReceive(clock) { now = $0 }
        .onChange(of: isArriving) { _, arriving in
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

    // MARK: - Cruise Mode

    private var cruiseModeContent: some View {
        VStack(spacing: 16) {

            // Live stats: time · distance · speed
            HStack(spacing: 0) {
                ACMetricsColumn(value: elapsedFormatted, label: "time")
                columnDivider
                ACMetricsColumn(value: cruiseDistanceFormatted, label: cruiseDistanceUnit)
                columnDivider
                ACMetricsColumn(value: currentSpeedString, label: "mph")
            }
            .padding(.horizontal, 16)

            // Friends on the road (if multiplayer session active)
            if let session = multiplayerService.activeSession, !session.members.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.Colors.acLeaf)
                    Text("\(session.members.count) friend\(session.members.count == 1 ? "" : "s") on the road")
                        .font(Theme.Typography.button)
                        .foregroundStyle(Theme.Colors.acLeaf)
                    Spacer()
                    // Mini avatar pills
                    HStack(spacing: -6) {
                        ForEach(session.members.prefix(3), id: \.id) { member in
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.acMint)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Theme.Colors.acField, lineWidth: 2))
                                Text(member.avatarURL ?? "🐾")
                                    .font(.system(size: 14))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Theme.Colors.acLeaf.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Theme.Colors.acLeaf.opacity(0.3), lineWidth: 1.5)
                )
                .padding(.horizontal, 16)
            }

            // Action buttons
            HStack(spacing: 12) {
                ACPillButton(title: "Find a Place", icon: "magnifyingglass", isFullWidth: true, action: { onSetDestination?() })
                ACDangerButton(title: "End Drive", action: onEnd)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Helpers

    private var columnDivider: some View {
        Rectangle()
            .fill(Theme.Colors.acBorder.opacity(0.4))
            .frame(width: 2, height: 44)
    }
}
