import SwiftUI

struct NavigationBottomPanel: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var multiplayerService: MultiplayerService

    var onEnd: () -> Void
    var onSetDestination: (() -> Void)?
    var departureTime: Date?
    var cruiseOdometerMiles: Double = 0

    @StateObject private var vm = NavigationBottomPanelViewModel()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    // MARK: - Computed Convenience

    private var routeDistanceMeters: Int { routingService.routeDistanceMeters }
    private var routeTimeSeconds: Int { routingService.routeTimeSeconds }
    private var distanceTraveledMeters: Double {
        locationProvider.isSimulating
            ? locationProvider.distanceTraveledInSimulationMeters
            : routingService.distanceTraveledMeters
    }

    private var routeProgress: Double {
        vm.routeProgress(routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)
    }

    private var isCruiseMode: Bool {
        routingService.activeRoute.isEmpty
    }

    private var isArriving: Bool {
        vm.isArriving(routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)
    }

    // Global Progress Bar
    var routeProgressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 6)

                Rectangle()
                    .fill(Theme.Colors.acLeaf) // Replaced Navigation blue with acLeaf
                    .frame(width: geo.size.width * max(0, min(1.0, routeProgress)), height: 6)
            }
        }
        .frame(height: 6)
    }

    var body: some View {
        VStack(spacing: 0) {
            if !isCruiseMode {
                routeProgressBar
            }

            if let quest = routingService.questManager.activeQuest {
                QuestProgressRibbon(
                    quest: quest,
                    currentStopNumber: routingService.questManager.currentStopNumber,
                    totalStopsInQuest: routingService.questManager.totalStopsInQuest,
                    currentStopName: routingService.questManager.currentStopName,
                    routeProgress: routeProgress
                )
            }

            if isCruiseMode {
                CruiseModeDashboard(
                    elapsedFormatted: vm.elapsedFormatted(departureTime: departureTime),
                    cruiseDistanceFormatted: vm.cruiseDistanceFormatted(cruiseOdometerMiles: cruiseOdometerMiles),
                    cruiseDistanceUnit: vm.cruiseDistanceUnit(cruiseOdometerMiles: cruiseOdometerMiles),
                    currentSpeedString: vm.currentSpeedString(currentSpeedMPH: locationProvider.currentSpeedMPH),
                    activeSessionMembers: multiplayerService.activeSession?.members ?? [],
                    onSetDestination: onSetDestination,
                    onEnd: onEnd
                )
            } else if isArriving {
                HStack {
                    Text("Almost there!")
                        .font(Theme.Typography.title)
                        .foregroundColor(Theme.Colors.acLeaf)
                        .opacity(vm.arrivingPulse ? 1.0 : 0.5)
                    Spacer()
                    Button(action: onEnd) {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .black))
                            .frame(width: 44, height: 44)
                            .background(Theme.Colors.acCoral)
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
                            Text("\(vm.remainingMinutes(routeTimeSeconds: routeTimeSeconds, routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters))")
                                .font(.system(size: 34, weight: .black, design: .rounded))
                                .foregroundColor(Theme.Colors.acLeaf) // Bright green ETA
                            Text("min")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acLeaf)
                        }

                        HStack(spacing: 6) {
                            Text("\(vm.distanceValue(routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)) \(vm.distanceUnit(routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters))")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.acTextDark.opacity(0.8))
                            Text("•")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.acTextDark.opacity(0.8))
                            Text("\(vm.arrivalTime(routeTimeSeconds: routeTimeSeconds, routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters))")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.acTextDark.opacity(0.8))
                        }
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 12) {
                        Button(action: {
                            onSetDestination?()
                        }) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 50, height: 50)
                                .background(Theme.Colors.acTextDark.opacity(0.1))
                                .foregroundColor(Theme.Colors.acTextDark)
                                .clipShape(Circle())
                        }

                        ShareLink(item: "I'm on my way! My ETA is \(vm.arrivalTime(routeTimeSeconds: routeTimeSeconds, routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)).") {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .bold))
                                .frame(width: 50, height: 50)
                                .background(Theme.Colors.acTextDark.opacity(0.1))
                                .foregroundColor(Theme.Colors.acTextDark)
                                .clipShape(Circle())
                        }

                        Button(action: onEnd) {
                            Text("Exit")
                                .font(Theme.Typography.button)
                                .frame(width: 60, height: 50)
                                .background(Theme.Colors.acCoral)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(Theme.Colors.acCream) // Changed to acCream for light woodsy feel
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Theme.Colors.acTextDark.opacity(0.15), radius: 10, x: 0, y: 5)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).strokeBorder(Theme.Colors.acBorder, lineWidth: 2))
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .onReceive(clock) { vm.now = $0 }
        .onChange(of: isArriving) { _, arriving in
            if !isCruiseMode && arriving {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    vm.arrivingPulse = true
                }
            } else {
                vm.arrivingPulse = false
            }
        }
    }
}
