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
    @StateObject private var parkingStore = ParkingStore()
    @StateObject private var owlPolice = OwlPolice()
    @StateObject private var routingService = RoutingService()
    @StateObject private var journal = RideJournal()
    @StateObject private var savedRoutes = SavedRoutesStore()
    @StateObject private var driveStore = DriveStore()
    @StateObject private var vehicleStore = VehicleStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraStore)
                .environmentObject(parkingStore)
                .environmentObject(owlPolice)
                .environmentObject(routingService)
                .environmentObject(journal)
                .environmentObject(savedRoutes)
                .environmentObject(driveStore)
                .environmentObject(vehicleStore)
                .preferredColorScheme(.dark)
                .onAppear {
                    owlPolice.startPatrol(with: cameraStore.cameras)
                }
        }
    }
}

struct ContentView: View {
    @State private var appState: AppState = {
        guard UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") else { return .onboarding }
        return .garage
    }()

    @State private var lastRideContext: RideContext? = nil
    @State private var pendingSession: PendingDriveSession? = nil
    @State private var postRideInfo: PostRideInfo? = nil
    @State private var pendingMoodSave: ((String) -> Void)? = nil

    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var journal: RideJournal
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var driveStore: DriveStore
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var routingService: RoutingService

    var body: some View {
        Group {
            switch appState {

            case .onboarding:
                OnboardingView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .garage }
                }

            case .garage:
                MapHomeView(
                    onRollOut: {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) { appState = .riding }
                    },
                    postRideInfo: postRideInfo,
                    pendingMoodSave: pendingMoodSave
                )
                .onAppear {
                    // Sync vehicle mode from store on every garage visit
                    routingService.vehicleMode = vehicleStore.selectedVehicleMode
                }

            case .riding:
                RideView(onStop: { context, pending in
                    lastRideContext = context
                    pendingSession = pending

                    // Build toast info from ride stats
                    let distanceMiles = pending?.distanceMiles ?? 0
                    let zenScore = pending?.zenScore ?? 0
                    let moneySaved = Double((pending?.cameraZoneEvents ?? []).filter { $0.outcome == .saved }.count) * 100
                    postRideInfo = PostRideInfo(distanceMiles: distanceMiles, zenScore: zenScore, moneySaved: moneySaved)

                    // Save drive session immediately (no mood yet)
                    if let p = pending {
                        let session = p.toSession(mood: nil)
                        driveStore.appendSession(
                            originCoord: p.originCoord,
                            destCoord: p.destCoord,
                            destinationName: p.destinationName,
                            session: session
                        )
                    }

                    // Record route visit
                    if let ctx = context {
                        savedRoutes.recordVisit(
                            destinationName: ctx.destinationName,
                            coordinate: ctx.destinationCoordinate,
                            durationSeconds: ctx.routeDurationSeconds,
                            departureTime: ctx.departureTime
                        )
                    }

                    // Mood save closure — called from MoodSelectionCard or on dismiss
                    let capturedContext = context
                    let capturedCamerasAvoided = owlPolice.camerasPassedThisRide
                    pendingMoodSave = { mood in
                        if !mood.isEmpty {
                            journal.addEntry(
                                mood: mood,
                                ticketsAvoided: capturedCamerasAvoided,
                                context: capturedContext
                            )
                        }
                        owlPolice.resetRideStats()
                        lastRideContext = nil
                        pendingSession = nil
                        postRideInfo = nil
                        pendingMoodSave = nil
                    }

                    owlPolice.stopNavigationSession()

                    // Immediately back to garage (background save already done above)
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { appState = .garage }
                })

            // WindDown kept for backward compatibility but not used in primary flow
            case .windDown:
                WindDownView(
                    ticketsAvoided: owlPolice.camerasPassedThisRide,
                    zenScore: owlPolice.zenScore,
                    rideContext: lastRideContext,
                    cameraZoneEvents: pendingSession?.cameraZoneEvents ?? []
                ) { mood in
                    journal.addEntry(mood: mood, ticketsAvoided: owlPolice.camerasPassedThisRide, context: lastRideContext)

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
        // Sync vehicleMode whenever selected vehicle changes
        .onChange(of: vehicleStore.selectedVehicleMode) { mode in
            routingService.vehicleMode = mode
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

            if routeState == .navigating && (owlPolice.currentZone == .approach || owlPolice.currentZone == .danger) {
                AlertOverlayView(camera: owlPolice.nearestCamera)
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
                            DigitalDashSpeedometer(owlPolice: owlPolice)
                                .transition(.scale.combined(with: .opacity))
                        }
                        .padding(.leading, 16)
                        .padding(.top, 16)

                        Spacer()

                        VStack(alignment: .trailing, spacing: 12) {
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
                                Button {
                                    owlPolice.isMuted.toggle()
                                } label: {
                                    Image(systemName: owlPolice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .font(.system(size: 22, weight: .bold))
                                        .frame(width: 64, height: 64)
                                        .foregroundColor(owlPolice.isMuted ? .red : .white)
                                }
                                .accessibilityLabel(owlPolice.isMuted ? "Unmute alerts" : "Mute alerts")

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
            // if routeState == .navigating && owlPolice.isMuted && !uiVisible {
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
                owlPolice.startNavigationSession()
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    routeState = .navigating
                    owlPolice.isSimulating = false
                }
            }, onSimulate: {
                guard !routingService.activeRoute.isEmpty else {
                    Log.warn("Navigation", "onSimulate called with empty activeRoute — aborting")
                    return
                }
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
        }
        .onChange(of: owlPolice.currentSpeedMPH) { speed in
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
        .onChange(of: owlPolice.currentLocation) { location in
            if routeState == .navigating, let loc = location {
                routingService.checkReroute(currentLocation: loc)
            }
        }
        .onChange(of: owlPolice.isSimulating) { isSimulating in
            if !isSimulating && routeState == .navigating {
                if !routingService.activeRoute.isEmpty {
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
