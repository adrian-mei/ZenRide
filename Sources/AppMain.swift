import SwiftUI

enum AppState {
    case onboarding
    case garage
    case riding
    case windDown
}

enum RouteState {
    case search
    case reviewing
    case navigating
}

@main
struct ZenRideApp: App {
    @StateObject private var cameraStore = CameraStore()
    @StateObject private var owlPolice = OwlPolice()
    @StateObject private var routingService = RoutingService()
    @StateObject private var journal = RideJournal()
    @StateObject private var savedRoutes = SavedRoutesStore()
    @StateObject private var driveStore = DriveStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraStore)
                .environmentObject(owlPolice)
                .environmentObject(routingService)
                .environmentObject(journal)
                .environmentObject(savedRoutes)
                .environmentObject(driveStore)
                .preferredColorScheme(.dark)
                .onAppear {
                    owlPolice.startPatrol(with: cameraStore.cameras)
                }
        }
    }
}

struct ContentView: View {
    @State private var appState: AppState =
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") ? .garage : .onboarding
    @State private var lastRideContext: RideContext? = nil
    @State private var pendingSession: PendingDriveSession? = nil
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var journal: RideJournal
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var driveStore: DriveStore

    var body: some View {
        Group {
            switch appState {
            case .onboarding:
                OnboardingView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .garage }
                }
            case .garage:
                GarageView(onRollOut: {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .riding }
                })
            case .riding:
                RideView(onStop: { context, pending in
                    lastRideContext = context
                    pendingSession = pending
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { appState = .windDown }
                })
            case .windDown:
                WindDownView(
                    ticketsAvoided: owlPolice.camerasPassedThisRide,
                    zenScore: owlPolice.zenScore,
                    rideContext: lastRideContext,
                    cameraZoneEvents: pendingSession?.cameraZoneEvents ?? []
                ) { mood in
                    // Save to legacy journal (backward compat)
                    journal.addEntry(mood: mood, ticketsAvoided: owlPolice.camerasPassedThisRide, context: lastRideContext)

                    // Save to rich DriveStore (new system)
                    if let pending = pendingSession {
                        let session = pending.toSession(mood: mood)
                        driveStore.appendSession(
                            originCoord: pending.originCoord,
                            destCoord: pending.destCoord,
                            destinationName: pending.destinationName,
                            session: session
                        )
                    }

                    if let ctx = lastRideContext {
                        savedRoutes.recordVisit(
                            destinationName: ctx.destinationName,
                            coordinate: ctx.destinationCoordinate,
                            durationSeconds: ctx.routeDurationSeconds,
                            departureTime: ctx.departureTime
                        )
                    }

                    owlPolice.resetRideStats()
                    lastRideContext = nil
                    pendingSession = nil
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .garage }
                }
            }
        }
    }
}

struct RideView: View {
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var routingService: RoutingService
    var onStop: (RideContext?, PendingDriveSession?) -> Void

    @StateObject private var searcher = DestinationSearcher()
    @State private var routeState: RouteState = .search
    @State private var destinationName: String = ""
    @State private var controlsVisible = true
    @State private var searchSheetDetent: PresentationDetent = .fraction(0.15)
    @State private var departureTime: Date? = nil
    @State private var navigationStartTime: Date? = nil

    var body: some View {
        ZStack(alignment: .top) {
            ZenMapView(routeState: $routeState)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture(count: 2) {
                    owlPolice.isMuted.toggle()
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(owlPolice.isMuted ? .error : .success)
                }

            if routeState == .navigating {
                AmbientGlowView()
                    .zIndex(1)
                    .transition(.opacity)
            }

            if routeState == .navigating && (owlPolice.currentZone == .approach || owlPolice.currentZone == .danger) {
                AlertOverlayView(camera: owlPolice.nearestCamera)
                    .zIndex(100)
            }

            // Top HUD
            VStack(spacing: 12) {
                if routeState == .navigating {
                    GuidanceView()
                        .padding(.top, 16)
                        .transition(.move(edge: .top))
                }

                if routeState == .search || routeState == .navigating {
                    HStack(alignment: .top) {
                        // Left Side: Speed Indicator
                        if routeState == .navigating {
                            DigitalDashSpeedometer(owlPolice: owlPolice)
                                .padding(.leading, 16)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            // Search Mode Mini-HUD (Just the Limit)
                            VStack(spacing: 0) {
                                Text("SPEED")
                                    .font(.system(size: 8, weight: .bold, design: .default))
                                    .foregroundColor(.black)
                                Text("LIMIT")
                                    .font(.system(size: 8, weight: .bold, design: .default))
                                    .foregroundColor(.black)
                                    .padding(.bottom, 2)
                                Text("\(owlPolice.nearestCamera?.speed_limit_mph ?? 45)")
                                    .font(.system(size: 26, weight: .bold, design: .default))
                                    .foregroundColor(.black)
                            }
                            .frame(width: 54, height: 64)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(Color.black, lineWidth: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(Color.black, lineWidth: 1)
                                    .padding(2)
                            )
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            .padding(.leading, 16)
                            .padding(.top, 16)
                        }

                        Spacer()

                        // Right Side: Map Controls Stack
                        VStack(alignment: .trailing, spacing: 12) {
                            if owlPolice.isMuted && routeState == .navigating {
                                HStack(spacing: 6) {
                                    Image(systemName: "speaker.slash.fill")
                                    Text("MUTED")
                                        .font(.caption.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.red.opacity(0.8), in: Capsule())
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                                .transition(.scale(scale: 0.85).combined(with: .opacity))
                            }
                            if routeState == .search && owlPolice.camerasPassedThisRide > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "leaf.fill")
                                        .font(.subheadline)
                                        .foregroundColor(.green)
                                    Text("$\(owlPolice.camerasPassedThisRide * 100)")
                                        .font(.subheadline.bold())
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(.regularMaterial, in: Capsule())
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }

                            VStack(spacing: 0) {
                                if routeState == .navigating {
                                    Button(action: {
                                        owlPolice.isMuted.toggle()
                                    }) {
                                        Image(systemName: owlPolice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    .accessibilityLabel(owlPolice.isMuted ? "Unmute alerts" : "Mute alerts")

                                    Divider().padding(.horizontal, 8).opacity(0.3)
                                }

                                Button(action: {
                                    NotificationCenter.default.post(name: NSNotification.Name("RecenterMap"), object: nil)
                                }) {
                                    Image(systemName: "location.fill")
                                        .font(.title3)
                                        .frame(width: 48, height: 48)
                                        .foregroundColor(routeState == .navigating ? .cyan : .primary)
                                }
                                .accessibilityLabel("Recenter map on your location")

                                if routeState == .navigating {
                                    Divider().padding(.horizontal, 8).opacity(0.3)

                                    Button(action: {
                                        reportHazard()
                                    }) {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                            .foregroundColor(.orange)
                                    }
                                    .accessibilityLabel("Report Hazard")
                                }
                            }
                            .frame(width: 48)
                            .foregroundColor(.white)
                            .background(
                                ZStack {
                                    Color(red: 0.1, green: 0.1, blue: 0.15)
                                    LinearGradient(colors: [.white.opacity(0.1), .clear], startPoint: .top, endPoint: .bottom)
                                }
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(routeState == .navigating ? Color.cyan.opacity(0.3) : Color.white.opacity(0.1), lineWidth: 1)
                            )
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                        }
                        .padding(.trailing, 16)
                        .padding(.top, routeState == .search ? 16 : 0)
                        .opacity(controlsVisible ? 1.0 : 0.0)
                    }
                    .transition(.opacity)
                }

                Spacer()

                if routeState == .navigating {
                    if controlsVisible {
                        NavigationBottomPanel(onEnd: {
                            endRide()
                        })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .edgesIgnoringSafeArea(.bottom)
                    }
                }
            }
        }
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
                .presentationDetents([.fraction(0.15), .medium, .large], selection: $searchSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled()
        }
        .onChange(of: searcher.searchQuery) { query in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                searchSheetDetent = query.isEmpty ? .fraction(0.15) : .medium
            }
        }
        .sheet(isPresented: Binding(
            get: { routeState == .reviewing },
            set: { _ in }
        )) {
            RouteSelectionSheet(destinationName: destinationName, onDrive: {
                departureTime = Date()
                navigationStartTime = Date()
                owlPolice.startNavigationSession()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    routeState = .navigating
                    owlPolice.isSimulating = false
                }
            }, onSimulate: {
                departureTime = Date()
                navigationStartTime = Date()
                owlPolice.startNavigationSession()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    routeState = .navigating
                    owlPolice.simulateDrive(along: routingService.activeRoute)
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
            .interactiveDismissDisabled()
        }
        .onChange(of: owlPolice.currentSpeedMPH) { speed in
            if speed > 15.0 && controlsVisible {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { controlsVisible = false }
            } else if speed < 12.0 && !controlsVisible {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { controlsVisible = true }
            }
        }
        .onChange(of: routeState) { state in
            if state == .navigating {
                UIApplication.shared.isIdleTimerDisabled = true
            } else {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        .onChange(of: owlPolice.currentLocation) { location in
            if routeState == .navigating, let loc = location {
                routingService.checkReroute(currentLocation: loc)
            }
        }
        .onChange(of: owlPolice.isSimulating) { isSimulating in
            if !isSimulating && routeState == .navigating {
                if !routingService.activeRoute.isEmpty && owlPolice.currentSimulationIndex >= routingService.activeRoute.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        if routeState == .navigating {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                routeState = .search
                                let context = buildRideContext()
                                let pending = buildPendingSession(context: context)
                                routingService.activeRoute = []
                                routingService.availableRoutes = []
                                routingService.activeAlternativeRoutes = []
                                owlPolice.stopNavigationSession()
                                onStop(context, pending)
                            }
                        }
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
            speedReadings: owlPolice.speedReadings,
            cameraZoneEvents: owlPolice.cameraZoneEvents,
            topSpeedMph: owlPolice.sessionTopSpeedMph,
            avgSpeedMph: owlPolice.sessionAvgSpeedMph,
            zenScore: owlPolice.zenScore,
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
        guard let location = owlPolice.currentLocation else { return }

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
        owlPolice.stopNavigationSession()
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            routingService.activeRoute = []
            routingService.availableRoutes = []
            routingService.activeAlternativeRoutes = []
            owlPolice.stopSimulation()
            onStop(context, pending)
        }
    }
}

struct AlertOverlayView: View {
    let camera: SpeedCamera?

    var body: some View {
        if let camera = camera {
            HStack(spacing: 20) {
                // Classic Speed Limit Sign Graphic
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 70, height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 3)
                        )

                    VStack(spacing: 0) {
                        Text("SPEED\nLIMIT")
                            .font(.system(size: 10, weight: .black))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding(.top, 8)

                        Text("\(camera.speed_limit_mph)")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundColor(.black)
                            .padding(.bottom, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("SPEED TRAP AHEAD")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 2)
                    Text("Roll off the throttle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Color(red: 0.9, green: 0.1, blue: 0.2).opacity(0.9)
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .background(.ultraThinMaterial)
            )
            .clipShape(RoundedCorner(radius: 24, corners: [.bottomLeft, .bottomRight]))
            .shadow(color: Color(red: 0.9, green: 0.1, blue: 0.2).opacity(0.6), radius: 20, x: 0, y: 10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct AmbientGlowView: View {
    @EnvironmentObject var owlPolice: OwlPolice
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Color(red: 0.0, green: 0.05, blue: 0.1).ignoresSafeArea()

            LinearGradient(colors: [glowColor, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: glowWidth * 4)
                .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(colors: [glowColor, .clear], startPoint: .bottom, endPoint: .top)
                .frame(height: glowWidth * 4)
                .frame(maxHeight: .infinity, alignment: .bottom)

            LinearGradient(colors: [glowColor, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: glowWidth * 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            LinearGradient(colors: [glowColor, .clear], startPoint: .trailing, endPoint: .leading)
                .frame(width: glowWidth * 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .edgesIgnoringSafeArea(.all)
        .opacity(owlPolice.currentZone == .danger ? (pulse ? 0.8 : 0.3) : 0.6)
        .allowsHitTesting(false)
        .onChange(of: owlPolice.currentZone) { zone in
            if zone == .danger {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                withAnimation {
                    pulse = false
                }
            }
        }
    }

    var glowColor: Color {
        switch owlPolice.currentZone {
        case .danger:   return Color(red: 0.9, green: 0.1, blue: 0.2)
        case .approach: return Color(red: 0.9, green: 0.5, blue: 0.0)
        case .safe:     return Color(red: 0.0, green: 0.5, blue: 1.0)
        }
    }

    var glowWidth: CGFloat {
        switch owlPolice.currentZone {
        case .danger:   return 60
        case .approach: return 30
        case .safe:     return 15
        }
    }
}
