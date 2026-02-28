import SwiftUI
import MapKit
import CoreLocation

// MARK: - Post-Ride Info

struct PostRideInfo {
    let distanceMiles: Double
    let zenScore: Int
    let moneySaved: Double
    let xpEarned: Int
}

// MARK: - MapHomeView

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

    @State private var showGarage = false
    @State private var showHistory = false
    @State private var showMoodCard = false
    @State private var showProfile = false
    @State private var toastVisible = false

    @State private var isTracking = true
    @State private var is3DMap = false
    @State private var bottomSheetDetent: PresentationDetent = .fraction(0.35)
    
    @State private var questWaypoints: [QuestWaypoint] = []
    @State private var showQuestBuilderFloating = false

    var body: some View {
        ZStack {
            // Full-screen interactive map
            ZenMapView(routeState: .constant(.search), isTracking: $isTracking)
                .edgesIgnoringSafeArea(.all)
                .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddPOIToRoute"))) { notif in
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
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    MapRoundButton(
                        icon: is3DMap ? "view.3d" : "map",
                        label: is3DMap ? "Switch to 2D map" : "Switch to 3D map",
                        isActive: is3DMap,
                        action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            is3DMap.toggle()
                            NotificationCenter.default.post(name: NSNotification.Name("Toggle3DMap"), object: is3DMap)
                        }
                    )
                    MapRoundButton(
                        icon: vehicleStore.selectedVehicleMode.icon,
                        label: "Open vehicle garage",
                        action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showGarage = true
                        }
                    )
                    MapRoundButton(
                        icon: isTracking ? "location.fill" : "location",
                        label: isTracking ? "Location tracking active" : "Center map on my location",
                        isActive: isTracking,
                        action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            isTracking = true
                            NotificationCenter.default.post(name: NSNotification.Name("RecenterMap"), object: nil)
                        }
                    )
                }
                .padding(.trailing, 16)
                // Positioned above the default 0.35 sheet detent so buttons remain visible
                .padding(.bottom, UIScreen.main.bounds.height * 0.38)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

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
                        withAnimation(.spring()) {
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
                VStack {
                    Spacer()
                    VStack(spacing: 12) {
                        HStack {
                            Text("Custom Route")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acTextDark)
                            Spacer()
                            Text("\(questWaypoints.count) stops")
                                .font(.subheadline.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(Theme.Colors.acLeaf.opacity(0.2))
                                .foregroundColor(Theme.Colors.acLeaf)
                                .clipShape(Capsule())
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(questWaypoints) { wp in
                                    HStack(spacing: 6) {
                                        Image(systemName: wp.icon)
                                            .foregroundColor(Theme.Colors.acLeaf)
                                        Text(wp.name)
                                            .font(Theme.Typography.body)
                                            .foregroundColor(Theme.Colors.acTextDark)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Theme.Colors.acField)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Theme.Colors.acBorder, lineWidth: 1))
                                }
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button("Clear") {
                                withAnimation {
                                    questWaypoints.removeAll()
                                    showQuestBuilderFloating = false
                                }
                            }
                            .font(Theme.Typography.button)
                            .foregroundColor(Theme.Colors.acCoral)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.Colors.acCoral.opacity(0.1))
                            .clipShape(Capsule())
                            
                            Button("Start Route") {
                                if questWaypoints.count >= 2 {
                                    let quest = DailyQuest(title: "Custom Route", waypoints: questWaypoints)
                                    routingService.startQuest(quest, currentLocation: locationProvider.currentLocation?.coordinate)
                                    withAnimation {
                                        questWaypoints.removeAll()
                                        showQuestBuilderFloating = false
                                    }
                                    onRollOut() // Go to RideView
                                } else {
                                    // Handle single destination
                                    if let first = questWaypoints.first {
                                        onDestinationSelected(first.name, first.coordinate)
                                        withAnimation {
                                            questWaypoints.removeAll()
                                            showQuestBuilderFloating = false
                                        }
                                    }
                                }
                            }
                            .font(Theme.Typography.button)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(Theme.Colors.acLeaf)
                            .clipShape(Capsule())
                        }
                    }
                    .padding()
                    .background(Theme.Colors.acCream)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
                    .padding(.horizontal)
                    .padding(.bottom, UIScreen.main.bounds.height * 0.15 + 20)
                }
                .zIndex(60)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(isPresented: .constant(true)) {
            HomeBottomSheet(
                onProfileTap: { showProfile = true },
                onDestinationSelected: onDestinationSelected,
                onCruiseTap: onRollOut,
                onSearchFocused: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        bottomSheetDetent = .large
                    }
                }
            )
            .presentationDetents([.fraction(0.15), .fraction(0.35), .large], selection: $bottomSheetDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .large))
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(24)
            .interactiveDismissDisabled()
        }
        .onAppear {
            if postRideInfo != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    toastVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.5)) { toastVisible = false }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if pendingMoodSave != nil {
                        withAnimation { showMoodCard = true }
                    }
                }
            }
        }
        .sheet(isPresented: $showGarage) {
            VehicleGarageView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showProfile) {
            ProfileView()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showHistory) {
            DriveHistoryView()
        }
        .sheet(isPresented: $showMoodCard) {
            if let moodSave = pendingMoodSave {
                MoodSelectionCard(onSelect: { mood in
                    moodSave(mood)
                    showMoodCard = false
                }, onDismiss: {
                    moodSave("")
                    showMoodCard = false
                })
                .presentationDetents([.fraction(0.45)])
                .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Map Round Button

struct MapRoundButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(isActive ? Theme.Colors.acLeaf : Theme.Colors.acTextDark)
                .frame(width: 52, height: 52)
                .background(isActive ? Theme.Colors.acLeaf.opacity(0.12) : Theme.Colors.acCream)
                .clipShape(Circle())
                .overlay(
                    Circle().stroke(
                        isActive ? Theme.Colors.acLeaf : Theme.Colors.acBorder,
                        lineWidth: isActive ? 2.5 : 2
                    )
                )
                .shadow(color: Theme.Colors.acBorder.opacity(0.8), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.bottom, 4)
        .accessibilityLabel(label)
        .contentShape(Circle())
    }
}

// MARK: - Home Bottom Sheet

struct HomeBottomSheet: View {
    var onProfileTap: () -> Void
    var onDestinationSelected: (String, CLLocationCoordinate2D) -> Void
    var onCruiseTap: () -> Void
    var onSearchFocused: (() -> Void)? = nil

    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var cameraStore: CameraStore
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var parkingStore: ParkingStore
    @EnvironmentObject var playerStore: PlayerStore

    @StateObject private var searcher = DestinationSearcher()
    @FocusState private var isSearchFocused: Bool
    @State private var searchTask: Task<Void, Never>?
    @State private var justSavedIndex: Int? = nil
    @State private var nearbyParking: [ParkingSpot] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Drag Handle
                CenterView {
                    Capsule()
                        .fill(Theme.Colors.acBorder)
                        .frame(width: 48, height: 6)
                        .padding(.top, 12)
                }

                // Search Bar + Profile / Cancel
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .font(.system(size: 16, weight: .bold))

                        TextField("Search Destinations", text: $searcher.searchQuery)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .onChange(of: searcher.searchQuery) { query in
                                searchTask?.cancel()
                                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                                    searcher.searchResults = []
                                    searcher.isSearching = false
                                    return
                                }
                                searcher.isSearching = true
                                searchTask = Task {
                                    try? await Task.sleep(nanoseconds: 180_000_000)
                                    guard !Task.isCancelled else { return }
                                    searcher.search(for: query, near: locationProvider.currentLocation?.coordinate)
                                }
                            }
                            .onSubmit {
                                searchTask?.cancel()
                                let q = searcher.searchQuery.trimmingCharacters(in: .whitespaces)
                                guard !q.isEmpty else { return }
                                searcher.isSearching = true
                                searcher.search(for: q, near: locationProvider.currentLocation?.coordinate)
                            }

                        if !searcher.searchQuery.isEmpty {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                searcher.searchQuery = ""
                                searcher.searchResults = []
                                searcher.isSearching = false
                                isSearchFocused = true
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(Theme.Colors.acTextMuted)
                                    .frame(width: 36, height: 36)
                            }
                        } else if !isSearchFocused {
                            Image(systemName: "mic.fill")
                                .foregroundColor(Theme.Colors.acTextMuted)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.Colors.acField)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))

                    if isSearchFocused {
                        Button("Cancel") {
                            isSearchFocused = false
                            searcher.searchQuery = ""
                            searcher.searchResults = []
                            searcher.isSearching = false
                        }
                        .font(Theme.Typography.button)
                        .foregroundColor(Theme.Colors.acWood)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        Button(action: onProfileTap) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 40, height: 40)
                                .foregroundColor(Theme.Colors.acLeaf)
                                .background(Circle().fill(Theme.Colors.acCream))
                                .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 2))
                        }
                    }
                }
                .padding(.horizontal)
                .animation(.spring(response: 0.35, dampingFraction: 0.8), value: isSearchFocused)

                // Content: search results or idle
                if !searcher.searchQuery.isEmpty {
                    searchResultsContent
                        .padding(.horizontal)
                } else {
                    idleContent
                }
            }
        }
        .background(Theme.Colors.acCream)
        // .preferredColorScheme(.dark) // Remove dark mode preference
        .scrollDismissesKeyboard(.interactively)
        .onAppear { refreshNearbyParking() }
        .onChange(of: isSearchFocused) { focused in
            if focused { onSearchFocused?() }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.82), value: searcher.searchQuery.isEmpty)
    }

    // MARK: - Idle Content

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Experience / Level Progress
            HStack {
                ZStack {
                    Circle()
                        .fill(Color(hex: playerStore.selectedCharacter.colorHex))
                        .frame(width: 50, height: 50)
                    Image(systemName: playerStore.selectedCharacter.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(playerStore.currentLevel)")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                    
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.Colors.acBorder.opacity(0.3))
                            Capsule()
                                .fill(Theme.Colors.acLeaf)
                                .frame(width: geo.size.width * playerStore.currentLevelProgress())
                        }
                    }
                    .frame(height: 8)
                }
                
                Spacer()
                
                Text("\(playerStore.totalXP) XP")
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Colors.acLeaf)
            }
            .padding(.horizontal)
            
            // Camp & Cruise Button
            Button(action: onCruiseTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Camp & Cruise")
                            .font(Theme.Typography.title)
                            .foregroundColor(.white)
                        Text("Start a Social Road Trip")
                            .font(Theme.Typography.body)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                    ZStack {
                        Image(systemName: "tent.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white.opacity(0.5))
                            .offset(x: -16, y: -4)
                        Image(systemName: "car.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .padding(20)
                .background(Theme.Colors.acLeaf)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color(hex: "388E3C"), lineWidth: 3))
                .shadow(color: Color(hex: "388E3C").opacity(0.8), radius: 0, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 6) // For shadow
            
            // FashodaMap: Daily Quests inject here!
            QuestDashboardView()
            
            // Pinned/Bookmarked Routes
            let pinned = savedRoutes.pinnedRoutes
            if !pinned.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Bookmarked")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        Image(systemName: "bookmark.fill")
                            .foregroundColor(Theme.Colors.acCoral)
                            .font(.caption.bold())
                    }
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(Array(pinned.enumerated()), id: \.element.id) { index, route in
                            let coord = CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude)
                            RecentRow(
                                icon: route.offlineRoute != nil ? "arrow.down.circle.fill" : "star.fill",
                                title: route.destinationName,
                                subtitle: route.offlineRoute != nil ? "Offline Route Available" : "Saved Destination",
                                iconColor: Theme.Colors.acCoral
                            ) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                let origin = locationProvider.currentLocation?.coordinate
                                    ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                                
                                if let offline = route.offlineRoute {
                                    routingService.loadOfflineRoute(offline)
                                } else {
                                    Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
                                }
                                onDestinationSelected(route.destinationName, coord)
                            }
                            if index < pinned.count - 1 {
                                Divider().background(Theme.Colors.acBorder.opacity(0.3)).padding(.leading, 50)
                            }
                        }
                    }
                    .background(Theme.Colors.acField)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.acBorder, lineWidth: 2))
                    .padding(.horizontal)
                }
            }
                
            // Places
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Places")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.Colors.acWood)
                        .font(.caption.bold())
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        placeChip(icon: "fuelpump.fill", color: Theme.Colors.acCoral, title: "Gas Station", query: "Gas Stations")
                        placeChip(icon: "cup.and.saucer.fill", color: Theme.Colors.acGold, title: "Coffee", query: "Coffee")
                        placeChip(icon: "parkingsign.circle.fill", color: Theme.Colors.acSky, title: "Parking", query: "Parking")
                        placeChip(icon: "wrench.and.screwdriver.fill", color: Theme.Colors.acWood, title: "Mechanic", query: "Motorcycle Repair")
                    }
                    .padding(.horizontal)
                }
            }

            // Recents
            let recents = savedRoutes.topRecent(limit: 3)
            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Recents")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        Image(systemName: "chevron.right")
                            .foregroundColor(Theme.Colors.acWood)
                            .font(.caption.bold())
                    }
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(Array(recents.enumerated()), id: \.element.id) { index, route in
                            let coord = CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude)
                            RecentRow(
                                icon: route.offlineRoute != nil ? "arrow.down.circle.fill" : "arrow.turn.up.right",
                                title: route.destinationName,
                                subtitle: relativeDate(route.lastUsedDate)
                            ) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                let origin = locationProvider.currentLocation?.coordinate
                                    ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                                
                                if let offline = route.offlineRoute {
                                    routingService.loadOfflineRoute(offline)
                                } else {
                                    Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
                                }
                                onDestinationSelected(route.destinationName, coord)
                            }
                            if index < recents.count - 1 {
                                Divider().background(Theme.Colors.acBorder.opacity(0.3)).padding(.leading, 50)
                            }
                        }
                    }
                    .background(Theme.Colors.acField)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.acBorder, lineWidth: 2))
                    .padding(.horizontal)
                }
            }

            // Guides
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Your Guides")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                    Image(systemName: "chevron.right")
                        .foregroundColor(Theme.Colors.acWood)
                        .font(.caption.bold())
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        GuideCard(title: "Bay Area Twisties", count: 12, icon: "mountain.2.fill", bgColor: Theme.Colors.acMint)
                        GuideCard(title: "Favorites", count: 5, icon: "star.fill", bgColor: Theme.Colors.acSky)
                    }
                    .padding(.horizontal)
                }
            }

            // Actions
            VStack(spacing: 12) {
                ActionButton(icon: "square.and.arrow.up", title: "Share My Location", color: Theme.Colors.acSky)
                ActionButton(icon: "mappin.and.ellipse", title: "Mark My Location", color: Theme.Colors.acCoral)
                ActionButton(icon: "exclamationmark.bubble", title: "Report an Issue", color: Theme.Colors.acGold)
            }
            .padding(.horizontal)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResultsContent: some View {
        if searcher.isSearching {
            VStack(spacing: 12) {
                ProgressView()
                    .scaleEffect(1.4)
                    .tint(Theme.Colors.acWood)
                Text("Searching…")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.acWood)
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .transition(.opacity)
        } else if searcher.searchResults.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(Theme.Colors.acTextMuted)
                Text("No results for \"\(searcher.searchQuery)\"")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.acTextMuted)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .transition(.opacity)
        } else {
            VStack(spacing: 0) {
                ForEach(Array(searcher.searchResults.prefix(12).enumerated()), id: \.offset) { idx, item in
                    let userLoc = locationProvider.currentLocation
                    let distanceString: String? = {
                        guard let userLoc, let placeLoc = item.placemark.location else { return nil }
                        let miles = userLoc.distance(from: placeLoc) / 1609.34
                        return miles < 0.1 ? "Nearby" : String(format: "%.1f mi", miles)
                    }()
                    SearchResultRow(
                        item: item,
                        isSaved: justSavedIndex == idx,
                        distanceString: distanceString
                    ) {
                        routeTo(item: item)
                    } onSave: {
                        guard let coord = item.placemark.location?.coordinate else { return }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        savedRoutes.savePlace(name: item.name ?? "Place", coordinate: coord)
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            justSavedIndex = idx
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                            withAnimation { justSavedIndex = nil }
                        }
                    }

                    if idx < min(searcher.searchResults.count, 12) - 1 {
                        Divider().background(Theme.Colors.acBorder.opacity(0.3)).padding(.leading, 66)
                    }
                }
            }
            .background(Theme.Colors.acField)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
            .padding(.bottom, 20)
            .transition(.opacity)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func placeChip(icon: String, color: Color, title: String, query: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            searcher.searchQuery = query
            isSearchFocused = true
        } label: {
            PlaceIcon(icon: icon, color: color, title: title)
        }
        .buttonStyle(.plain)
    }

    private func routeTo(item: MKMapItem) {
        guard let coord = item.placemark.location?.coordinate else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        let name = item.name ?? "Destination"
        savedRoutes.addRecentSearch(
            name: name,
            subtitle: item.placemark.zenFormattedAddress,
            coordinate: coord
        )
        let origin = locationProvider.currentLocation?.coordinate
            ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
        searcher.searchResults = []
        searcher.searchQuery = ""
        isSearchFocused = false
        onDestinationSelected(name, coord)
    }

    private func refreshNearbyParking() {
        let refLat = locationProvider.currentLocation?.coordinate.latitude ?? 37.7749
        let refLng = locationProvider.currentLocation?.coordinate.longitude ?? -122.4194
        let sorted = parkingStore.spots.sorted {
            let d0 = ($0.latitude - refLat) * ($0.latitude - refLat) + ($0.longitude - refLng) * ($0.longitude - refLng)
            let d1 = ($1.latitude - refLat) * ($1.latitude - refLat) + ($1.longitude - refLng) * ($1.longitude - refLng)
            return d0 < d1
        }
        nearbyParking = Array(sorted.prefix(5))
    }

    private func relativeDate(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }
}

// MARK: - Supporting Views

struct CenterView<Content: View>: View {
    @ViewBuilder let content: () -> Content
    var body: some View {
        HStack {
            Spacer()
            content()
            Spacer()
        }
    }
}

struct PlaceIcon: View {
    let icon: String
    let color: Color
    let title: String

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(color)
                    .frame(width: 62, height: 62)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.Colors.acBorder, lineWidth: 2)
                    )
                    .shadow(color: color.opacity(0.45), radius: 0, x: 0, y: 4)
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text(title)
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acTextDark)
        }
    }
}

struct RecentRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var iconColor: Color = Theme.Colors.acLeaf
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconColor.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(iconColor)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Colors.acBorder)
            }
            .padding(.vertical, 13)
            .padding(.horizontal, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct GuideCard: View {
    let title: String
    let count: Int
    let icon: String
    let bgColor: Color

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(bgColor)
                .frame(width: 140, height: 180)
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
                .shadow(color: Theme.Colors.acBorder.opacity(0.8), radius: 0, x: 0, y: 4)

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundColor(Theme.Colors.acTextDark.opacity(0.6))
                        .padding(8)
                }
                Spacer()
            }

            CenterView {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(Theme.Colors.acCream.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(2)
                Text("\(count) places")
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
            .padding(12)
        }
        .frame(width: 140, height: 180)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String
    var color: Color = Theme.Colors.acWood

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(color.opacity(0.15))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(color)
                }
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Colors.acBorder)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(Theme.Colors.acField)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 2))
            .shadow(color: Theme.Colors.acBorder.opacity(0.7), radius: 0, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Post-Ride Toast

private struct PostRideToast: View {
    let info: PostRideInfo

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.acLeaf.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(Theme.Colors.acLeaf)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MISSION COMPLETE")
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Colors.acLeaf)
                    .kerning(1)
                HStack(spacing: 8) {
                    Text(String(format: "%.1f mi", info.distanceMiles))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextDark)
                    
                    if info.xpEarned > 0 {
                        Text("· +\(info.xpEarned) XP")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acLeaf)
                            .bold()
                    }
                    
                    if info.zenScore > 0 {
                        Text("· ZEN \(info.zenScore)")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextMuted)
                    }
                    if info.moneySaved > 0 {
                        Text("· +$\(Int(info.moneySaved))")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acWood)
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Colors.acCream)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acBorder, lineWidth: 2))
        .shadow(color: Theme.Colors.acBorder.opacity(0.8), radius: 0, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }
}

// MARK: - Level Up Toast

private struct LevelUpToast: View {
    let level: Int
    let characters: [Character]
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.acGold.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: "star.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Theme.Colors.acGold)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("LEVEL UP!")
                    .font(Theme.Typography.button)
                    .foregroundColor(Theme.Colors.acGold)
                    .kerning(1)
                Text("You reached Level \(level)")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                
                if !characters.isEmpty {
                    Text("Unlocked \(characters.map { $0.name }.joined(separator: ", "))!")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.Colors.acCream)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.Colors.acGold, lineWidth: 2))
        .shadow(color: Theme.Colors.acGold.opacity(0.4), radius: 0, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.top, 50)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                onDismiss()
            }
        }
    }
}

// MARK: - Mood Selection Card

struct MoodSelectionCard: View {
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    private let moods: [(emoji: String, label: String, color: Color)] = [
        ("😌", "Peaceful", Theme.Colors.acSky),
        ("🏕️", "Adventurous", Theme.Colors.acCoral),
        ("🥱", "Tiring", Theme.Colors.acWood)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Capsule()
                    .fill(Theme.Colors.acBorder)
                    .frame(width: 48, height: 6)
                    .padding(.top, 12)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acWood.opacity(0.2))
                            .frame(width: 48, height: 48)
                            .overlay(Circle().stroke(Theme.Colors.acWood, lineWidth: 2))
                        Text("🦉")
                            .font(.system(size: 26))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("BUNNY DEBRIEF")
                            .font(Theme.Typography.button)
                            .foregroundColor(Theme.Colors.acWood)
                            .kerning(1.5)
                        Text("How was the mission?")
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.acTextDark)
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)

                HStack(spacing: 16) {
                    ForEach(moods, id: \.label) { mood in
                        Button {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            onSelect(mood.label)
                        } label: {
                            VStack(spacing: 8) {
                                Text(mood.emoji)
                                    .font(.system(size: 32))
                                Text(mood.label.uppercased())
                                    .font(Theme.Typography.button)
                                    .foregroundColor(Theme.Colors.acTextDark)
                                    .kerning(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(mood.color.opacity(0.3))
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(mood.color, lineWidth: 2))
                            .shadow(color: mood.color.opacity(0.5), radius: 0, x: 0, y: 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 24)

                Button {
                    onDismiss()
                } label: {
                    Text("Skip for now")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                .padding(.bottom, 20)
            }
        }
        .background(Theme.Colors.acCream.ignoresSafeArea())
    }
}
