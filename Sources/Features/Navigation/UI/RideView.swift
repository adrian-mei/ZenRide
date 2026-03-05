import SwiftUI
import MapKit
import CoreLocation
import Combine

struct RideView: View {
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var multiplayerService: MultiplayerService
    @EnvironmentObject var memoryStore: MemoryStore

    let initialDestinationName: String
    var onStop: (RideContext?, PendingDriveSession?) -> Void

    @StateObject private var vm: RideViewModel

    init(initialDestinationName: String, onStop: @escaping (RideContext?, PendingDriveSession?) -> Void) {
        self.initialDestinationName = initialDestinationName
        self.onStop = onStop
        _vm = StateObject(wrappedValue: RideViewModel(initialDestinationName: initialDestinationName))
    }

    var body: some View {
        ZStack(alignment: .top) {
                        ZenMapView(routeState: $vm.routeState, isTracking: $vm.isTracking, mapMode: vm.mapMode, onMapTap: {
                if vm.routeState == .navigating {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        vm.uiVisible = true
                        vm.showTapHint = false
                    }
                }
            })
            .ignoresSafeArea(.all)

            if vm.routeState == .navigating && (bunnyPolice.currentZone == .approach || bunnyPolice.currentZone == .danger) {
                AlertOverlayView(camera: bunnyPolice.nearestCamera)
                    .allowsHitTesting(false)
                    .zIndex(100)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if vm.routeState == .navigating && routingService.showReroutePrompt {
                ReroutePromptOverlay()
                    .zIndex(101)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            if let stopName = vm.celebrationStopName {
                QuestCelebrationOverlay(
                    stopName: stopName,
                    isFinal: routingService.questManager.activeQuest == nil,
                    onDismiss: { vm.celebrationStopName = nil }
                )
                .zIndex(200)
                .transition(.scale(scale: 0.85).combined(with: .opacity))
            }

            mainUIChrome

            ACSnapshotEffect(isTriggered: $vm.flashTriggered)
                .zIndex(300)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: bunnyPolice.currentZone)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: routingService.showReroutePrompt)
        .animation(.spring(response: 0.5, dampingFraction: 0.75), value: vm.celebrationStopName != nil)
                .onAppear {
            vm.setup(
                routingService: routingService,
                bunnyPolice: bunnyPolice,
                locationProvider: locationProvider,
                multiplayerService: multiplayerService,
                onStop: onStop
            )
            vm.handleOnAppear()
        }
        .sheet(isPresented: Binding(
            get: { vm.routeState == .reviewing },
            set: { _ in }
        )) {
            selectionSheet
        }
        .sheet(isPresented: $vm.showCruiseSearch) {
            CruiseSearchSheet { name, coord in
                vm.showCruiseSearch = false
                vm.destinationName = name
                let origin = locationProvider.currentLocation?.coordinate
                    ?? coord
                Task {
                    await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: bunnyPolice.cameras)
                }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    vm.routeState = .reviewing
                }
            }
        }
        .onChange(of: vm.routeState) { _, newValue in handleRouteStateChange(newValue) }
        .onChange(of: locationProvider.currentLocation) { _, newValue in vm.handleLocationChange(newValue) }
        .onChange(of: locationProvider.simulationCompletedNaturally) { _, newValue in vm.handleSimulationCompletion(newValue) }
    }



    private var mainUIChrome: some View {
        ZStack {
            if vm.routeState == .navigating && vm.uiVisible {
                // Top Left: Guidance / Quests
                VStack(alignment: .center, spacing: 12) {
                    if routingService.questManager.activeQuest != nil {
                        QuestProgressView()
                    }
                    TurnByTurnHUDView()
                    Spacer()
                }
                .padding(.top, 16)
                .frame(maxWidth: .infinity, alignment: .top)

                // Top Right: Controls
                VStack(alignment: .trailing) {
                    controlsColumn
                    Spacer()
                }
                .padding(.top, 130)
                .frame(maxWidth: .infinity, alignment: .trailing)

                // Bottom Left: Speedometer
                VStack {
                    Spacer()
                    HStack {
                        DigitalDashSpeedometer()
                            .padding(.leading, 12)
                            .padding(.bottom, 150)
                        Spacer()
                    }
                }

                // Bottom Center: Navigation Panel
                VStack {
                    Spacer()
                    NavigationBottomPanel(
                        onEnd: { vm.endRide() },
                        onSetDestination: { vm.showCruiseSearch = true },
                        departureTime: vm.departureTime,
                        cruiseOdometerMiles: vm.cruiseOdometerMiles
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .zIndex(5)
    }



    private var controlsColumn: some View {
        VStack(alignment: .trailing, spacing: 12) {
            RideControlsView(
                mapMode: $vm.mapMode,
                isTracking: $vm.isTracking,
                onRecenter: {
                    NotificationCenter.default.post(name: AppNotification.recenterMap, object: nil)
                },
                onReportHazard: {
                    vm.reportHazard()
                }
            )
        }
        .padding(.trailing, 16)
        .transition(.opacity)
    }

    private var selectionSheet: some View {
        RouteSelectionSheet(destinationName: vm.destinationName, onDrive: {
            guard !routingService.activeRoute.isEmpty else { return }
            vm.departureTime = Date()
            vm.navigationStartTime = Date()
            bunnyPolice.startNavigationSession()
            vm.audioCoordinator.prefetchTTS(for: vm.destinationName, instructions: routingService.instructions, activeQuest: routingService.questManager.activeQuest)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                vm.routeState = .navigating
                locationProvider.isSimulating = false
                vm.uiVisible = true
                vm.showTapHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation { vm.showTapHint = false }
            }
        }, onSimulate: {
            guard !routingService.activeRoute.isEmpty else { return }
            vm.departureTime = Date()
            vm.navigationStartTime = Date()
            bunnyPolice.startNavigationSession()
            vm.audioCoordinator.prefetchTTS(for: vm.destinationName, instructions: routingService.instructions, activeQuest: routingService.questManager.activeQuest)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                vm.routeState = .navigating
                locationProvider.simulateDrive(along: routingService.activeRoute, speedMPH: routingService.vehicleMode.simulationSpeedMPH)
                vm.uiVisible = true
                vm.showTapHint = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                withAnimation { vm.showTapHint = false }
            }
        }, onCancel: {
            vm.endRide()
        })
        .presentationDetents([.fraction(0.2), .medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)
        .interactiveDismissDisabled()
    }



    private func handleRouteStateChange(_ state: RouteState) {
        if state == .navigating {
            UIApplication.shared.isIdleTimerDisabled = true
        } else {
            UIApplication.shared.isIdleTimerDisabled = false
            withAnimation { vm.uiVisible = true }
        }
    }














}