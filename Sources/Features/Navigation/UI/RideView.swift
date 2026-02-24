import SwiftUI
import MapKit
import CoreLocation
import Combine

struct RideView: View {
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService

    let initialDestinationName: String
    var onStop: (RideContext?, PendingDriveSession?) -> Void

    @State private var routeState: RouteState
    @State private var destinationName: String
    @State private var uiVisible = true
    @State private var showTapHint = false
    @State private var departureTime: Date? = nil
    @State private var navigationStartTime: Date? = nil
    @State private var isTracking: Bool = true

    init(initialDestinationName: String, onStop: @escaping (RideContext?, PendingDriveSession?) -> Void) {
        self.initialDestinationName = initialDestinationName
        self.onStop = onStop
        _destinationName = State(initialValue: initialDestinationName)
        _routeState = State(initialValue: .reviewing)
    }

    var body: some View {
        ZStack(alignment: .top) {
            ZenMapView(routeState: $routeState, isTracking: $isTracking)
                .ignoresSafeArea(.all)

            if routeState == .navigating {
                AmbientGlowView()
                    .allowsHitTesting(false)
                    .zIndex(1)
                    .transition(.opacity)
            }

            if routeState == .navigating && (bunnyPolice.currentZone == .approach || bunnyPolice.currentZone == .danger) {
                AlertOverlayView(camera: bunnyPolice.nearestCamera)
                    .allowsHitTesting(false)
                    .zIndex(100)
            }

            // Main UI chrome
            VStack(spacing: 12) {
                // Turn-by-turn HUD — always visible while navigating
                if routeState == .navigating {
                    GuidanceView()
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Controls row — only shown while navigating
                if routeState == .navigating {
                    HStack(alignment: .top) {
                        // Always show the full Digital Dash Speedometer
                        VStack(alignment: .leading, spacing: 20) {
                            DigitalDashSpeedometer(bunnyPolice: bunnyPolice, locationProvider: locationProvider)
                                .transition(.scale.combined(with: .opacity))
                        }
                        .padding(.leading, 16)
                        .padding(.top, 16)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 12) {
                            VStack(spacing: 0) {
                                Button {
                                    bunnyPolice.isMuted.toggle()
                                } label: {
                                    Image(systemName: bunnyPolice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .frame(width: 64, height: 64)
                                        .foregroundColor(bunnyPolice.isMuted ? .red : .white)
                                }
                                .accessibilityLabel(bunnyPolice.isMuted ? "Unmute alerts" : "Mute alerts")

                                Divider().padding(.horizontal, 10).opacity(0.3)

                                Button {
                                    NotificationCenter.default.post(name: NSNotification.Name("RecenterMap"), object: nil)
                                } label: {
                                    Image(systemName: isTracking ? "location.fill" : "location")
                                        .font(.system(size: 22, weight: .bold))
                                        .frame(width: 64, height: 64)
                                        .foregroundColor(isTracking ? .cyan : .white)
                                }
                                .accessibilityLabel("Recenter map on your location")

                                Divider().padding(.horizontal, 10).opacity(0.3)

                                Button { reportHazard() } label: {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 26, weight: .black))
                                        .frame(width: 64, height: 64)
                                        .foregroundColor(.yellow)
                                        .shadow(color: .orange.opacity(0.8), radius: 6)
                                }
                                .accessibilityLabel("Report Hazard")
                            }
                            .frame(width: 64)
                            .foregroundColor(.white)
                            .background(
                                ZStack {
                                    Color(red: 0.05, green: 0.05, blue: 0.08).opacity(0.5)
                                    LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)
                                }
                                .background(.ultraThinMaterial)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.cyan.opacity(0.3), lineWidth: 1.0)
                            )
                            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                    .transition(.opacity)
                }

                Spacer()

                // Bottom navigation panel
                if routeState == .navigating {
                    NavigationBottomPanel(onEnd: { endRide() })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .zIndex(5)
        }
        .sheet(isPresented: Binding(
            get: { routeState == .reviewing },
            set: { _ in }
        )) {
            RouteSelectionSheet(destinationName: destinationName, onDrive: {
                guard !routingService.activeRoute.isEmpty else {
                    Log.warn("Navigation", "onDrive called with empty activeRoute — aborting")
                    return
                }
                departureTime = Date()
                navigationStartTime = Date()
                bunnyPolice.startNavigationSession()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    routeState = .navigating
                    locationProvider.isSimulating = false
                }
            }, onSimulate: {
                guard !routingService.activeRoute.isEmpty else {
                    Log.warn("Navigation", "onSimulate called with empty activeRoute — aborting")
                    return
                }
                departureTime = Date()
                navigationStartTime = Date()
                bunnyPolice.startNavigationSession()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    routeState = .navigating
                    locationProvider.simulateDrive(along: routingService.activeRoute)
                }
            }, onCancel: {
                endRide()
            })
            .presentationDetents([.fraction(0.2), .medium, .large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled)
            .interactiveDismissDisabled()
        }
        .onChange(of: locationProvider.currentSpeedMPH) { _ in
            // Speed-based auto-hide disabled per user request
        }
        .onChange(of: routeState) { state in
            if state == .navigating {
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                UIApplication.shared.isIdleTimerDisabled = false
                withAnimation { uiVisible = true }
            }
        }
        .onChange(of: locationProvider.currentLocation) { location in
            if routeState == .navigating, let loc = location {
                routingService.checkReroute(currentLocation: loc)
            }
        }
        .onChange(of: locationProvider.simulationCompletedNaturally) { completed in
            guard completed && routeState == .navigating else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                if routeState == .navigating {
                    endRide()
                }
            }
        }
    }

    private func buildRideContext() -> RideContext? {
        guard !destinationName.isEmpty, let departure = departureTime else { return nil }
        guard let destCoord = routingService.activeRoute.last,
              let originCoord = routingService.activeRoute.first else { return nil }
        return RideContext(
            destinationName: destinationName,
            destinationCoordinate: destCoord,
            originCoordinate: originCoord,
            routeDurationSeconds: routingService.routeTimeSeconds,
            routeDistanceMeters: routingService.routeDistanceMeters,
            departureTime: departure
        )
    }

    private func buildPendingSession(context: RideContext?) -> PendingDriveSession? {
        guard let ctx = context, let startTime = navigationStartTime else { return nil }
        let actualDuration = Int(Date().timeIntervalSince(startTime))
        let distanceMiles = Double(ctx.routeDistanceMeters) / 1609.34
        return PendingDriveSession(
            speedReadings: bunnyPolice.speedReadings,
            cameraZoneEvents: bunnyPolice.cameraZoneEvents,
            topSpeedMph: bunnyPolice.sessionTopSpeedMph,
            avgSpeedMph: bunnyPolice.sessionAvgSpeedMph,
            zenScore: bunnyPolice.zenScore,
            departureTime: ctx.departureTime,
            actualDurationSeconds: max(actualDuration, ctx.routeDurationSeconds),
            distanceMiles: distanceMiles,
            originCoord: ctx.originCoordinate,
            destCoord: ctx.destinationCoordinate,
            destinationName: ctx.destinationName,
            routeDurationSeconds: ctx.routeDurationSeconds
        )
    }

    private func reportHazard() {
        guard let location = locationProvider.currentLocation else { return }
        NotificationCenter.default.post(
            name: NSNotification.Name("DropHazardPin"),
            object: location.coordinate
        )
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.success)
    }

    private func endRide() {
        let context = buildRideContext()
        let pending = buildPendingSession(context: context)
        bunnyPolice.stopNavigationSession()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            routingService.activeRoute = []
            routingService.availableRoutes = []
            routingService.activeAlternativeRoutes = []
            locationProvider.stopSimulation()
            onStop(context, pending)
        }
    }
}

/// Returns true when a sheet dismissal should reset navigation state back to search.
/// Extracted for testability: the sheet binding `set` closure calls this to avoid
/// overwriting `.navigating` when the sheet is dismissed by a Simulate/Drive tap.
func shouldResetOnSheetDismiss(routeState: RouteState) -> Bool {
    routeState != .navigating
}
