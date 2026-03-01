import SwiftUI
import MapKit
import CoreLocation
import Combine

struct RideView: View {
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var multiplayerService: MultiplayerService

    let initialDestinationName: String
    var onStop: (RideContext?, PendingDriveSession?) -> Void

    @State private var routeState: RouteState
    @State private var destinationName: String
    @State private var uiVisible = true
    @State private var showTapHint = false
    @State private var departureTime: Date? = nil
    @State private var navigationStartTime: Date? = nil
    @State private var isTracking: Bool = true
    @State private var mapMode: MapMode = .turnByTurn
    @State private var cruiseOdometerMiles: Double = 0
    @State private var cruiseLastLocation: CLLocation? = nil
    @State private var showCruiseSearch = false
    @State private var celebrationStopName: String? = nil

    init(initialDestinationName: String, onStop: @escaping (RideContext?, PendingDriveSession?) -> Void) {
        self.initialDestinationName = initialDestinationName
        self.onStop = onStop
        _destinationName = State(initialValue: initialDestinationName)
        _routeState = State(initialValue: initialDestinationName.isEmpty ? .navigating : .reviewing)
    }

    var body: some View {
        ZStack(alignment: .top) {
            mapLayer
            
            if routeState == .navigating && (bunnyPolice.currentZone == .approach || bunnyPolice.currentZone == .danger) {
                AlertOverlayView(camera: bunnyPolice.nearestCamera)
                    .allowsHitTesting(false)
                    .zIndex(100)
            }

            if routeState == .navigating && routingService.showReroutePrompt {
                ReroutePromptOverlay()
                    .zIndex(101)
            }

            if let stopName = celebrationStopName {
                QuestCelebrationOverlay(
                    stopName: stopName,
                    isFinal: routingService.activeQuest == nil,
                    onDismiss: { celebrationStopName = nil }
                )
                .zIndex(200)
            }

            mainUIChrome
        }
        .onAppear(perform: handleOnAppear)
        .sheet(isPresented: Binding(
            get: { routeState == .reviewing },
            set: { _ in }
        )) {
            selectionSheet
        }
        .sheet(isPresented: $showCruiseSearch) {
            CruiseSearchSheet { name, coord in
                showCruiseSearch = false
                destinationName = name
                let origin = locationProvider.currentLocation?.coordinate
                    ?? coord
                Task {
                    await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: bunnyPolice.cameras)
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    routeState = .reviewing
                }
            }
        }
        .onChange(of: routeState) { _, newValue in handleRouteStateChange(newValue) }
        .onChange(of: locationProvider.currentLocation) { _, newValue in handleLocationChange(newValue) }
        .onChange(of: locationProvider.simulationCompletedNaturally) { _, newValue in handleSimulationCompletion(newValue) }
    }

    private var mapLayer: some View {
        ZenMapView(routeState: $routeState, isTracking: $isTracking, mapMode: mapMode, onMapTap: {
            if routeState == .navigating {
                withAnimation(.easeInOut(duration: 0.3)) {
                    uiVisible = true
                    showTapHint = false
                }
            }
        })
        .ignoresSafeArea(.all)
    }

    private var mainUIChrome: some View {
        ZStack {
            if routeState == .navigating && uiVisible {
                // Top Left: Guidance / Quests
                VStack(alignment: .leading, spacing: 12) {
                    if routingService.activeQuest != nil {
                        QuestProgressView()
                    }
                    turnByTurnHUD
                    Spacer()
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
                
                // Top Right: Controls
                VStack(alignment: .trailing) {
                    controlsColumn
                    Spacer()
                }
                .padding(.top, 70)
                .frame(maxWidth: .infinity, alignment: .trailing)
                
                // Bottom Left: Speedometer
                VStack {
                    Spacer()
                    HStack {
                        DigitalDashSpeedometer()
                            .scaleEffect(0.55)
                            .frame(width: 80, height: 80)
                            .padding(.leading, 8)
                            .padding(.bottom, 110)
                        Spacer()
                    }
                }

                // Bottom Center: Navigation Panel
                VStack {
                    Spacer()
                    NavigationBottomPanel(
                        onEnd: { endRide() },
                        onSetDestination: { showCruiseSearch = true },
                        departureTime: departureTime,
                        cruiseOdometerMiles: cruiseOdometerMiles
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .zIndex(5)
    }

    private var turnByTurnHUD: some View {
        GuidanceView()
            .transition(.move(edge: .leading).combined(with: .opacity))
    }

    private var controlsColumn: some View {
        VStack(alignment: .trailing, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    mapMode = (mapMode == .turnByTurn) ? .overview : .turnByTurn
                }
            } label: {
                Image(systemName: mapMode == .turnByTurn ? "map.fill" : "location.north.fill")
                    .font(.system(size: 20, weight: .bold))
                    .frame(width: 48, height: 48)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .background(Theme.Colors.acCream)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 2))
                    .shadow(color: Theme.Colors.acBorder.opacity(0.5), radius: 0, x: 0, y: 4)
            }
            
            VStack(spacing: 0) {
                Button {
                    bunnyPolice.isMuted.toggle()
                } label: {
                    Image(systemName: bunnyPolice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 48, height: 48)
                        .foregroundColor(bunnyPolice.isMuted ? Theme.Colors.acCoral : Theme.Colors.acTextDark)
                }

                Divider().background(Theme.Colors.acBorder.opacity(0.3)).padding(.horizontal, 10)

                Button {
                    isTracking = true
                    NotificationCenter.default.post(name: NSNotification.Name("RecenterMap"), object: nil)
                } label: {
                    Image(systemName: isTracking ? "location.fill" : "location")
                        .font(.system(size: 20, weight: .bold))
                        .frame(width: 48, height: 48)
                        .foregroundColor(Theme.Colors.acTextDark)
                }

                Divider().background(Theme.Colors.acBorder.opacity(0.3)).padding(.horizontal, 10)

                Button { reportHazard() } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 22, weight: .black))
                        .frame(width: 48, height: 48)
                        .foregroundColor(Theme.Colors.acGold)
                }
            }
            .frame(width: 48)
            .background(Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
            .shadow(color: Theme.Colors.acBorder.opacity(0.5), radius: 0, x: 0, y: 4)
        }
        .padding(.trailing, 16)
        .transition(.opacity)
    }

    private var selectionSheet: some View {
        RouteSelectionSheet(destinationName: destinationName, onDrive: {
            guard !routingService.activeRoute.isEmpty else { return }
            departureTime = Date()
            navigationStartTime = Date()
            bunnyPolice.startNavigationSession()
            prefetchTTS(for: destinationName)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                routeState = .navigating
                locationProvider.isSimulating = false
                uiVisible = true
                showTapHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation { showTapHint = false }
            }
        }, onSimulate: {
            guard !routingService.activeRoute.isEmpty else { return }
            departureTime = Date()
            navigationStartTime = Date()
            bunnyPolice.startNavigationSession()
            prefetchTTS(for: destinationName)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                routeState = .navigating
                locationProvider.simulateDrive(along: routingService.activeRoute)
                uiVisible = true
                showTapHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation { showTapHint = false }
            }
        }, onCancel: {
            endRide()
        })
        .presentationDetents([.fraction(0.2), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
    }
    
    private func handleOnAppear() {
        if initialDestinationName.isEmpty {
            departureTime = Date()
            navigationStartTime = Date()
            bunnyPolice.startNavigationSession()
            locationProvider.isSimulating = false
            showTapHint = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation { showTapHint = false }
            }
        }
    }
    
    private func handleRouteStateChange(_ state: RouteState) {
        if state == .navigating {
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            UIApplication.shared.isIdleTimerDisabled = false
            withAnimation { uiVisible = true }
        }
    }
    
    private func handleLocationChange(_ location: CLLocation?) {
        guard routeState == .navigating, let loc = location else { return }
        routingService.checkReroute(currentLocation: loc)
        bunnyPolice.processLocation(loc, speedMPH: locationProvider.currentSpeedMPH)
        multiplayerService.broadcastLocalLocation(
            coordinate: loc.coordinate,
            heading: loc.course >= 0 ? loc.course : 0,
            speedMph: locationProvider.currentSpeedMPH,
            route: routingService.activeRoute,
            etaSeconds: routingService.routeTimeSeconds
        )
        if routingService.activeRoute.isEmpty {
            if let last = cruiseLastLocation {
                let deltaMeters = loc.distance(from: last)
                if deltaMeters < 800 {
                    cruiseOdometerMiles += deltaMeters / 1609.34
                }
            }
            cruiseLastLocation = loc
        }
    }
    
    private func handleSimulationCompletion(_ completed: Bool) {
        guard completed && routeState == .navigating else { return }
        
        if let quest = routingService.activeQuest {
            let reachedStopName = quest.waypoints[routingService.currentStopNumber].name
            celebrationStopName = reachedStopName
            
            if let loc = locationProvider.currentLocation?.coordinate {
                let advanced = routingService.advanceToNextLeg(currentLocation: loc)
                if advanced {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        if !routingService.activeRoute.isEmpty && celebrationStopName == nil {
                            locationProvider.simulateDrive(along: routingService.activeRoute)
                        }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
                        endRide()
                    }
                }
            }
        } else {
            celebrationStopName = destinationName
            DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
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
    
    private func prefetchTTS(for destinationName: String) {
        var prefetchTexts = [String]()
        let dest = destinationName.isEmpty ? "your destination" : destinationName
        prefetchTexts.append("Route to \(dest) is ready. Let's have a wonderful trip together!")
        prefetchTexts.append("You have arrived at your final destination. Route complete!")
        for instruction in routingService.instructions {
            prefetchTexts.append("In 500 feet, \(instruction.text)")
            prefetchTexts.append(instruction.text)
        }
        if let quest = routingService.activeQuest {
            for i in 0..<(quest.waypoints.count - 1) {
                let current = quest.waypoints[i].name
                let next = quest.waypoints[i + 1].name
                prefetchTexts.append("Arrived at \(current). Next stop is \(next). Route is ready when you are.")
            }
        }
        SpeechService.shared.prefetch(texts: prefetchTexts)
    }
}
