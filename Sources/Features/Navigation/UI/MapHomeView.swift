import SwiftUI
import MapKit
import CoreLocation

enum MapActiveSheet: Identifiable {
    case garage, profile, moodCard
    var id: Self { self }
}

struct MapHomeView: View {
    @EnvironmentObject var journal: RideJournal
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var driveStore: DriveStore
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var playerStore: PlayerStore

    var onRollOut: () -> Void
    var onDestinationSelected: (String, CLLocationCoordinate2D) -> Void
    var postRideInfo: PostRideInfo?
    var pendingMoodSave: ((String) -> Void)?

    @State private var activeSheet: MapActiveSheet?
    @State private var toastVisible = false

    @State private var isTracking = true
    @State private var is3DMap = false
    @State private var bottomSheetDetent: PresentationDetent = .fraction(0.35)
    @State private var mapRouteState: RouteState = .search

    @State private var questWaypoints: [QuestWaypoint] = []
    @State private var showQuestBuilderFloating = false

    private func performRollOut() {
        mapRouteState = .navigating
        onRollOut()
    }

    var body: some View {
        ZStack {
            // Full-screen interactive map
            ZenMapView(routeState: $mapRouteState, isTracking: $isTracking)
                .ignoresSafeArea()
                .onReceive(NotificationCenter.default.publisher(for: AppNotification.addPOIToRoute)) { notif in
                    if let poi = notif.object as? POIAnnotation {
                        let wp = QuestWaypoint(
                            name: poi.title ?? "Stop \(questWaypoints.count + 1)",
                            coordinate: poi.coordinate,
                            icon: poi.type == .emergency ? "cross.case.fill" : "mappin.circle.fill"
                        )
                        questWaypoints.append(wp)
                        withAnimation {
                            showQuestBuilderFloating = true
                        }
                    }
                }

            // Right side buttons
            GeometryReader { geo in
                VStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ACMapRoundButton(
                            icon: is3DMap ? "view.3d" : "map",
                            label: is3DMap ? "Switch to 2D map" : "Switch to 3D map",
                            isActive: is3DMap,
                            action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                is3DMap.toggle()
                                NotificationCenter.default.post(name: AppNotification.toggle3DMap, object: is3DMap)
                            }
                        )
                        ACMapRoundButton(
                            icon: vehicleStore.selectedVehicleMode.icon,
                            label: "Open vehicle garage",
                            action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                activeSheet = .garage
                            }
                        )
                        ACMapRoundButton(
                            icon: isTracking ? "location.fill" : "location",
                            label: isTracking ? "Location tracking active" : "Center map on my location",
                            isActive: isTracking,
                            action: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                isTracking = true
                                NotificationCenter.default.post(name: AppNotification.recenterMap, object: nil)
                            }
                        )
                    }
                    .padding(.trailing, 16)
                    .padding(.bottom, geo.size.height * 0.38)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Post-ride toast
            if toastVisible, let info = postRideInfo {
                VStack {
                    PostRideToast(info: info)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .allowsHitTesting(false)
                .zIndex(50)
            }

            // Level Up Toast
            if playerStore.showLevelUpToast {
                VStack {
                    LevelUpToast(level: playerStore.currentLevel, characters: playerStore.newlyUnlockedCharacters) {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            playerStore.showLevelUpToast = false
                        }
                    }
                    .padding(.top, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    Spacer()
                }
                .zIndex(55)
            }

            // Achievement Unlock Toast
            if let achievement = playerStore.newlyEarnedAchievement {
                VStack {
                    AchievementUnlockToast(achievement: achievement)
                        .padding(.top, playerStore.showLevelUpToast ? 120 : 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                                withAnimation(.easeOut) {
                                    playerStore.newlyEarnedAchievement = nil
                                }
                            }
                        }
                    Spacer()
                }
                .zIndex(60)
            }

            if showQuestBuilderFloating && !questWaypoints.isEmpty {
                FloatingQuestBuilderOverlay(
                    questWaypoints: $questWaypoints,
                    showQuestBuilderFloating: $showQuestBuilderFloating,
                    onDestinationSelected: onDestinationSelected
                )
                .zIndex(60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onAppear {
            if postRideInfo != nil {
                mapRouteState = .search
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    toastVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.5)) { toastVisible = false }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if pendingMoodSave != nil {
                        withAnimation { activeSheet = .moodCard }
                    }
                }
            }
        }
        .sheet(isPresented: .constant(true)) {
            HomeBottomSheet(
                onProfileTap: { activeSheet = .profile },
                onDestinationSelected: onDestinationSelected,
                onCruiseTap: performRollOut,
                onRollOut: performRollOut,
                onSearchFocused: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        bottomSheetDetent = .large
                    }
                }
            )
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .garage:
                    VehicleGarageView()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .profile:
                    ProfileView()
                        .presentationDetents([.large])
                        .presentationDragIndicator(.visible)
                case .moodCard:
                    if let moodSave = pendingMoodSave {
                        MoodSelectionCard(onSelect: { mood in
                            moodSave(mood)
                            activeSheet = nil
                        }, onDismiss: {
                            moodSave("")
                            activeSheet = nil
                        })
                        .presentationDetents([.fraction(0.45)])
                        .presentationDragIndicator(.visible)
                    }
                }
            }
            .presentationDetents([.fraction(0.15), .fraction(0.35), .large], selection: $bottomSheetDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
            .interactiveDismissDisabled()
        }
    }
}
