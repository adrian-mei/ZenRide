import SwiftUI
import MapKit
import CoreLocation
import Combine

struct RideView: View {
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    var onStop: (RideContext?, PendingDriveSession?) -> Void

    @StateObject private var searcher = DestinationSearcher()
    @State private var routeState: RouteState = .search
    @State private var destinationName: String = ""
    @State private var uiVisible = true
    @State private var showTapHint = false
    @State private var searchSheetDetent: PresentationDetent = .fraction(0.35)
    @State private var departureTime: Date? = nil
    @State private var navigationStartTime: Date? = nil
    @State private var isTracking: Bool = true

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
                // Exit-to-garage button — only shown in search mode (no route selected yet)
                if routeState == .search {
                    HStack {
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                                endRide()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 14, weight: .bold))
                                Text("Garage")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color.black.opacity(0.7))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(Color.white.opacity(0.2), lineWidth: 1))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

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
                            if routeState == .search && bunnyPolice.camerasPassedThisRide > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "leaf.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                    Text("$\(bunnyPolice.camerasPassedThisRide * 100)")
                                        .font(.subheadline.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }

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
                                    Color(red: 0.05, green: 0.05, blue: 0.08).opacity(0.8)
                                    LinearGradient(colors: [.white.opacity(0.15), .clear], startPoint: .top, endPoint: .bottom)
                                }
                                .background(.ultraThinMaterial)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(Color.cyan.opacity(0.4), lineWidth: 1.5)
                            )
                            .shadow(color: .black.opacity(0.4), radius: 10, x: 0, y: 6)
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
                        .edgesIgnoringSafeArea(.bottom)
                }

                // "Tap to show controls" hint — disabled
                // if routeState == .navigating && showTapHint {
                //     ...
                // }
            }
            .zIndex(5)

            // Muted status pill no longer needed since controls are always visible
            // if routeState == .navigating && bunnyPolice.isMuted && !uiVisible {
            // ...
            // }
        }
        // .onTapGesture {
        //     guard routeState == .navigating else { return }
        //     withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
        //         uiVisible.toggle()
        //         if uiVisible { showTapHint = false }
        //     }
        // }
        .sheet(isPresented: Binding(
            get: { routeState == .search },
            set: { _ in }
        )) {
            DestinationSearchView(searcher: searcher, routeState: $routeState, destinationName: $destinationName,
                                  onSearchFocused: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    searchSheetDetent = .medium
                }
            })
                .presentationDetents([.fraction(0.14), .fraction(0.35), .medium, .large], selection: $searchSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled()
        }
        .onChange(of: searcher.searchQuery) { query in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                if !query.isEmpty {
                    searchSheetDetent = .medium
                }
                // Don't auto-collapse when clearing, let the user manually collapse
            }
        }
        .sheet(isPresented: Binding(
            get: { routeState == .reviewing },
            set: { isPresented in
                if !isPresented {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        routeState = .search
                        destinationName = ""
                        routingService.availableRoutes = []
                        routingService.activeRoute = []
                        routingService.activeAlternativeRoutes = []
                    }
                }
            }
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    routeState = .search
                    destinationName = ""
                    routingService.availableRoutes = []
                    routingService.activeRoute = []
                    routingService.activeAlternativeRoutes = []
                }
            })
            .presentationDetents([.medium, .fraction(0.3)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: locationProvider.currentSpeedMPH) { speed in
            // Speed-based auto-hide disabled per user request
            // if speed > 15.0 && uiVisible && routeState == .navigating {
            //     withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { uiVisible = false }
            // }
        }
        .onChange(of: routeState) { state in
            if state == .navigating {
                UIApplication.shared.isIdleTimerDisabled = true
                // Auto-hide disabled per user request
                // withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { uiVisible = false }
                // showTapHint = true
                // DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                //     withAnimation(.easeOut(duration: 0.6)) { showTapHint = false }
                // }
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
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        routeState = .search
                        let context = buildRideContext()
                        let pending = buildPendingSession(context: context)
                        routingService.activeRoute = []
                        routingService.availableRoutes = []
                        routingService.activeAlternativeRoutes = []
                        bunnyPolice.stopNavigationSession()
                        onStop(context, pending)
                    }
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
