import SwiftUI

enum AppState {
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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cameraStore)
                .environmentObject(owlPolice)
                .environmentObject(routingService)
                .environmentObject(journal)
                .preferredColorScheme(.dark)
                .onAppear {
                    owlPolice.startPatrol(with: cameraStore.cameras)
                }
        }
    }
}

struct ContentView: View {
    @State private var appState: AppState = .riding
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var journal: RideJournal
    
    var body: some View {
        Group {
            switch appState {
            case .garage:
                GarageView(onRollOut: {
                    withAnimation { appState = .riding }
                })
            case .riding:
                RideView(onStop: {
                    withAnimation { appState = .windDown }
                })
            case .windDown:
                WindDownView(ticketsAvoided: owlPolice.camerasPassedThisRide) { mood in
                    journal.addEntry(mood: mood, ticketsAvoided: owlPolice.camerasPassedThisRide)
                    owlPolice.resetRideStats()
                    withAnimation { appState = .riding } // Skip garage to maintain maps clone feel
                }
            }
        }
    }
}

struct RideView: View {
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var routingService: RoutingService
    var onStop: () -> Void
    
    @State private var routeState: RouteState = .search
    @State private var destinationName: String = ""
    
    var body: some View {
        ZStack(alignment: .top) {
            ZenMapView(routeState: $routeState)
                .edgesIgnoringSafeArea(.all)
                
            if routeState == .navigating {
                AmbientGlowView()
                    .zIndex(1)
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
                        VStack(alignment: .center, spacing: 4) {
                            VStack(spacing: 0) {
                            Text("SPEED")
                                .font(.system(size: 8, weight: .bold, design: .default))
                                .foregroundColor(.black)
                            Text("LIMIT")
                                .font(.system(size: 8, weight: .bold, design: .default))
                                .foregroundColor(.black)
                                .padding(.bottom, 2)
                            Text("\(owlPolice.nearestCamera?.speed_limit_mph ?? 45)") // Show the actual speed limit, not current speed, inside the sign!
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
                        
                            // NEW: Early Speed Drop Anticipation Badge
                            if owlPolice.currentZone == .safe, 
                               let nearest = owlPolice.nearestCamera, 
                               owlPolice.distanceToNearestFT > 500 && owlPolice.distanceToNearestFT < 3000,
                               owlPolice.currentSpeedMPH > Double(nearest.speed_limit_mph) {
                                
                                HStack(spacing: 2) {
                                    Image(systemName: "arrow.down")
                                        .font(.system(size: 10, weight: .bold))
                                    Text("\(nearest.speed_limit_mph)")
                                        .font(.system(size: 12, weight: .black))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .background(Color.orange, in: Capsule())
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                                .transition(.opacity.combined(with: .scale))
                                .animation(.easeInOut, value: owlPolice.distanceToNearestFT)
                            }
                        } // End of outer VStack container
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                        .padding(.leading, 16)
                        .padding(.top, routeState == .search ? 16 : 0)
                        
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
                                    Button(action: {}) {
                                        Image(systemName: "magnifyingglass")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                    
                                    Button(action: {}) {
                                        Image(systemName: "speaker.wave.2.fill")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                } else {
                                    Button(action: {}) {
                                        Image(systemName: "map.fill")
                                            .font(.title3)
                                            .frame(width: 48, height: 48)
                                    }
                                    Divider().padding(.horizontal, 8)
                                }
                                
                                Button(action: {}) {
                                    Image(systemName: "location.fill")
                                        .font(.title3)
                                        .frame(width: 48, height: 48)
                                }
                            }
                            .frame(width: 48) // Strict constraint for layout issue
                            .foregroundColor(.primary)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            
                            if routeState == .navigating {
                                Button(action: {}) {
                                    Image(systemName: "exclamationmark.bubble.fill")
                                        .font(.title3)
                                        .frame(width: 48, height: 48)
                                }
                                .foregroundColor(.primary)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                            }
                        }
                        .padding(.trailing, 16)
                        .padding(.top, routeState == .search ? 16 : 0)
                        // FADE OUT CONTROLS WHILE DRIVING TO MAXIMIZE MAP
                        .opacity(owlPolice.currentSpeedMPH > 15.0 ? 0.0 : 1.0)
                        .animation(.easeInOut(duration: 0.5), value: owlPolice.currentSpeedMPH > 15.0)
                    }
                    .transition(.opacity)
                }
                
                Spacer()
                
                if routeState == .navigating {
                    NavigationBottomPanel(onEnd: {
                        endRide()
                    })
                    .transition(.move(edge: .bottom))
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 100, coordinateSpace: .local)
                .onEnded { value in
                    if routeState == .navigating && value.translation.height > 100 {
                        endRide()
                    }
                }
        )
        .onTapGesture(count: 2) {
            owlPolice.isMuted.toggle()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(owlPolice.isMuted ? .error : .success)
        }
        .sheet(isPresented: Binding(
            get: { routeState == .search },
            set: { _ in }
        )) {
            DestinationSearchView(routeState: $routeState, destinationName: $destinationName)
                .presentationDetents([.fraction(0.15), .medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackgroundInteraction(.enabled)
                .interactiveDismissDisabled()
        }
        .sheet(isPresented: Binding(
            get: { routeState == .reviewing },
            set: { _ in }
        )) {
            RouteSelectionSheet(destinationName: destinationName, onGo: {
                withAnimation {
                    routeState = .navigating
                    owlPolice.simulateDrive(along: routingService.activeRoute)
                }
            }, onCancel: {
                withAnimation {
                    routeState = .search
                    routingService.availableRoutes = []
                    routingService.activeRoute = []
                    routingService.activeAlternativeRoutes = []
                }
            })
            .presentationDetents([.medium, .fraction(0.3)])
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled()
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
                            withAnimation {
                                routeState = .search
                                routingService.activeRoute = []
                                routingService.availableRoutes = []
                                routingService.activeAlternativeRoutes = []
                                onStop()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func endRide() {
        withAnimation {
            routeState = .search
            routingService.activeRoute = []
            routingService.availableRoutes = []
            routingService.activeAlternativeRoutes = []
            owlPolice.stopSimulation()
            onStop()
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
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.white)
                        .frame(width: 70, height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
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
                    Text("SPEED CAMERA AHEAD")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(.white)
                    Text("Reduce speed now")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(Color.red)
            .shadow(color: .black.opacity(0.5), radius: 10, x: 0, y: 5)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

struct AmbientGlowView: View {
    @EnvironmentObject var owlPolice: OwlPolice
    @State private var pulse: Bool = false
    
    var body: some View {
        ZStack {
            if owlPolice.currentZone != .safe {
                LinearGradient(colors: [glowColor, .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: glowWidth * 3)
                    .frame(maxHeight: .infinity, alignment: .top)
                
                LinearGradient(colors: [glowColor, .clear], startPoint: .bottom, endPoint: .top)
                    .frame(height: glowWidth * 3)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                
                LinearGradient(colors: [glowColor, .clear], startPoint: .leading, endPoint: .trailing)
                    .frame(width: glowWidth * 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                LinearGradient(colors: [glowColor, .clear], startPoint: .trailing, endPoint: .leading)
                    .frame(width: glowWidth * 3)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
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
        case .danger: return .red
        case .approach: return .orange
        case .safe: return .clear
        }
    }
    
    var glowWidth: CGFloat {
        switch owlPolice.currentZone {
        case .danger: return 40
        case .approach: return 20
        case .safe: return 0
        }
    }
}