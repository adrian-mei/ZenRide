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
    var onSetDestination: (() -> Void)?
    var departureTime: Date?
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
            : String(format: "%.1f", remainingDistanceMeters / Constants.metersPerMile)
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

    // Global Progress Bar
    var routeProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 4)

                Rectangle()
                    .fill(Color(hex: "007AFF")) // Navigation blue
                    .frame(width: geo.size.width * max(0, min(1.0, routeProgress)), height: 4)
            }
        }
        .frame(height: 4)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isCruiseMode {
                routeProgressBar
            }

            if let quest = routingService.activeQuest {
                questProgressRibbon(quest: quest)
            }

            if isCruiseMode {
                cruiseModeContent
            } else if isArriving {
                HStack {
                    Text("Almost there!")
                        .font(Theme.Typography.title)
                        .foregroundColor(Color(hex: "4CAF50"))
                        .opacity(arrivingPulse ? 1.0 : 0.5)
                    Spacer()
                    Button(action: onEnd) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .frame(width: 44, height: 44)
                            .background(Color(hex: "FF3B30"))
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("End Route")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(remainingMinutes)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "4CD964")) // Bright green ETA
                            Text("min")
                                .font(.system(size: 20, weight: .semibold, design: .rounded))
                                .foregroundColor(Color(hex: "4CD964"))
                        }

                        HStack(spacing: 6) {
                            Text("\(distanceValue) \(distanceUnit)")
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(Color.white.opacity(0.7))
                            Text("•")
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(Color.white.opacity(0.7))
                            Text("\(arrivalTime)")
                                .font(.system(size: 16, weight: .medium, design: .default))
                                .foregroundColor(Color.white.opacity(0.7))
                        }
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 12) {
                        Button(action: {
                            onSetDestination?()
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }

                        ShareLink(item: "I'm on my way! My ETA is \(arrivalTime).") {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .semibold))
                                .frame(width: 50, height: 50)
                                .background(Color.white.opacity(0.15))
                                .foregroundColor(.white)
                                .clipShape(Circle())
                        }

                        Button(action: onEnd) {
                            Text("Exit")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .frame(width: 60, height: 50)
                                .background(Color(hex: "FF3B30")) // Bright red standard exit
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(Color(hex: "1C1C1E")) // Dark mode background
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
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

    // MARK: - Quest Progress

    @ViewBuilder
    private func questProgressRibbon(quest: DailyQuest) -> some View {
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

                Text("STOP \(routingService.currentStopNumber) OF \(routingService.totalStopsInQuest)")
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

                    let total = Double(routingService.totalStopsInQuest)
                    let current = Double(routingService.currentStopNumber)
                    let legProgress = routeProgress / total
                    let overallProgress = (max(0, current - 1) / total) + legProgress

                    Capsule()
                        .fill(Color(hex: "4CD964"))
                        .frame(width: geo.size.width * min(1.0, overallProgress), height: 4)
                }
            }
            .frame(height: 4)
            .padding(.horizontal, 16)

            if !routingService.currentStopName.isEmpty {
                Text("Next: \(routingService.currentStopName)")
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

    // MARK: - Cruise Mode

    private var cruiseModeContent: some View {
        VStack(spacing: 16) {

            // Live stats: time · distance · speed
            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Text(elapsedFormatted)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("time")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                columnDivider
                VStack(spacing: 4) {
                    Text(cruiseDistanceFormatted)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text(cruiseDistanceUnit)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                columnDivider
                VStack(spacing: 4) {
                    Text(currentSpeedString)
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Text("mph")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(Color.white.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 16)

            // Friends on the road (if multiplayer session active)
            if let session = multiplayerService.activeSession, !session.members.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: "4CD964"))
                    Text("\(session.members.count) friend\(session.members.count == 1 ? "" : "s") on the road")
                        .font(Theme.Typography.button)
                        .foregroundStyle(Color(hex: "4CD964"))
                    Spacer()
                    // Mini avatar pills
                    HStack(spacing: -6) {
                        ForEach(session.members.prefix(3), id: \.id) { member in
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.acMint)
                                    .frame(width: 28, height: 28)
                                    .overlay(Circle().stroke(Color(hex: "1C1C1E"), lineWidth: 2))
                                Text(member.avatarURL ?? "🐾")
                                    .font(.system(size: 14))
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color(hex: "4CD964").opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color(hex: "4CD964").opacity(0.3), lineWidth: 1.5)
                )
                .padding(.horizontal, 16)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { onSetDestination?() }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Find Place")
                    }
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.15))
                    .foregroundColor(.white)
                    .clipShape(Capsule())
                }

                Button(action: onEnd) {
                    Text("End")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                        .background(Color(hex: "FF3B30"))
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .padding(.top, 16)
    }

    // MARK: - Helpers

    private var columnDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1, height: 44)
    }
}
