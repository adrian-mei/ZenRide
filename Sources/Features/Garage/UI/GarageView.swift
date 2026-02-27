import SwiftUI
import MapKit
import CoreLocation

// MARK: - Post-Ride Info

struct PostRideInfo {
    let distanceMiles: Double
    let zenScore: Int
    let moneySaved: Double
}

// MARK: - MapHomeView

struct MapHomeView: View {
    @EnvironmentObject var journal: RideJournal
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @EnvironmentObject var driveStore: DriveStore
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider

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
    @State private var bottomSheetDetent: PresentationDetent = .fraction(0.35)

    var body: some View {
        ZStack {
            // Full-screen interactive map
            ZenMapView(routeState: .constant(.search), isTracking: $isTracking)
                .edgesIgnoringSafeArea(.all)

            // Right side buttons
            VStack {
                Spacer()
                VStack(spacing: 8) {
                    MapRoundButton(icon: "view.3d", action: {
                        // Action for 3D view
                    })
                    MapRoundButton(icon: vehicleStore.selectedVehicle?.type.icon ?? "car.fill", action: {
                        showGarage = true
                    })
                    MapRoundButton(icon: isTracking ? "location.fill" : "location", action: {
                        isTracking = true
                        NotificationCenter.default.post(name: NSNotification.Name("RecenterMap"), object: nil)
                    })
                }
                .padding(.trailing, 16)
                .padding(.bottom, UIScreen.main.bounds.height * 0.15 + 20)
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
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 48, height: 48)
                .background(Color(white: 0.15).opacity(0.9))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
                        .fill(Color.secondary.opacity(0.4))
                        .frame(width: 40, height: 5)
                        .padding(.top, 8)
                }

                // Search Bar + Profile / Cancel
                HStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 16, weight: .medium))

                        TextField("Search Destinations", text: $searcher.searchQuery)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                            .autocorrectionDisabled()
                            .font(.system(size: 17))
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
                                    .foregroundColor(.secondary)
                                    .frame(width: 36, height: 36)
                            }
                        } else if !isSearchFocused {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.secondary)
                                .frame(width: 36, height: 36)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                    if isSearchFocused {
                        Button("Cancel") {
                            isSearchFocused = false
                            searcher.searchQuery = ""
                            searcher.searchResults = []
                            searcher.isSearching = false
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.cyan)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    } else {
                        Button(action: onProfileTap) {
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .frame(width: 36, height: 36)
                                .foregroundColor(.cyan)
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
        .background(Color(.systemBackground))
        .preferredColorScheme(.dark)
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
            
            // Just Drive / Cruise Button
            Button(action: onCruiseTap) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Just Drive")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                        Text("Cruise with Bunny Police alerts")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    Spacer()
                    Image(systemName: "car.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.white)
                }
                .padding(20)
                .background(
                    LinearGradient(
                        colors: [.cyan.opacity(0.8), .blue.opacity(0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: .cyan.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 8)
            
            // FashodaMap: Daily Quests inject here!
            QuestDashboardView()
                
            // Places
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Places")
                        .font(.title3.bold())
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption.bold())
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        placeChip(icon: "fuelpump.fill", color: .green, title: "Gas Station", query: "Gas Stations")
                        placeChip(icon: "cup.and.saucer.fill", color: .orange, title: "Coffee", query: "Coffee")
                        placeChip(icon: "parkingsign.circle.fill", color: .blue, title: "Parking", query: "Parking")
                        placeChip(icon: "wrench.and.screwdriver.fill", color: .gray, title: "Mechanic", query: "Motorcycle Repair")
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
                            .font(.title3.bold())
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption.bold())
                    }
                    .padding(.horizontal)

                    VStack(spacing: 0) {
                        ForEach(Array(recents.enumerated()), id: \.element.id) { index, route in
                            let coord = CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude)
                            RecentRow(
                                icon: "arrow.turn.up.right",
                                title: route.destinationName,
                                subtitle: relativeDate(route.lastUsedDate)
                            ) {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                let origin = locationProvider.currentLocation?.coordinate
                                    ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
                                Task { await routingService.calculateSafeRoute(from: origin, to: coord, avoiding: cameraStore.cameras) }
                                onDestinationSelected(route.destinationName, coord)
                            }
                            if index < recents.count - 1 {
                                Divider().padding(.leading, 50)
                            }
                        }
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                    .padding(.horizontal)
                }
            }

            // Guides
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Your Guides")
                        .font(.title3.bold())
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption.bold())
                }
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        GuideCard(title: "Bay Area Twisties", count: 12, icon: "mountain.2.fill", bgGradient: [.blue, .purple])
                        GuideCard(title: "Favorites", count: 5, icon: "star.fill", bgGradient: [.orange, .yellow])
                    }
                    .padding(.horizontal)
                }
            }

            // Actions
            VStack(spacing: 12) {
                ActionButton(icon: "square.and.arrow.up", title: "Share My Location")
                ActionButton(icon: "mappin.and.ellipse", title: "Mark My Location")
                ActionButton(icon: "exclamationmark.bubble", title: "Report an Issue")
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
                    .tint(.cyan)
                Text("Searching…")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.cyan.opacity(0.8))
                    .kerning(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .transition(.opacity)
        } else if searcher.searchResults.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 32))
                    .foregroundStyle(.tertiary)
                Text("No results for \"\(searcher.searchQuery)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
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
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                Circle()
                    .fill(color)
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
            }
            Text(title)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

struct RecentRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.bold())
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "ellipsis")
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
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
    let bgGradient: [Color]

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: 16)
                .fill(LinearGradient(colors: bgGradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 140, height: 180)

            VStack {
                HStack {
                    Spacer()
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white.opacity(0.8))
                        .padding(8)
                }
                Spacer()
            }

            CenterView {
                Image(systemName: icon)
                    .font(.system(size: 60))
                    .foregroundColor(.white.opacity(0.8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)
                Text("\(count) places")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(12)
        }
        .frame(width: 140, height: 180)
    }
}

struct ActionButton: View {
    let icon: String
    let title: String

    var body: some View {
        Button(action: {}) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body.bold())
                    .foregroundColor(.cyan)
                    .frame(width: 24)
                Text(title)
                    .font(.body.bold())
                    .foregroundColor(.cyan)
                Spacer()
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
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
                    .fill(Color.green.opacity(0.2))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.green)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("MISSION COMPLETE")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundColor(.green)
                    .kerning(1)
                HStack(spacing: 8) {
                    Text(String(format: "%.1f mi", info.distanceMiles))
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                    if info.zenScore > 0 {
                        Text("· ZEN \(info.zenScore)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan.opacity(0.9))
                    }
                    if info.moneySaved > 0 {
                        Text("· +$\(Int(info.moneySaved))")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.9))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(red: 0.04, green: 0.1, blue: 0.08)
                Color.green.opacity(0.1)
            }
            .background(.ultraThinMaterial)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.green.opacity(0.4), lineWidth: 1))
        .shadow(color: Color.green.opacity(0.25), radius: 12, x: 0, y: 5)
        .padding(.horizontal, 16)
        .padding(.top, 50)
    }
}

// MARK: - Mood Selection Card

struct MoodSelectionCard: View {
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    private let moods: [(emoji: String, label: String, color: Color)] = [
        ("😌", "Peaceful", .cyan),
        ("🏕️", "Adventurous", .orange),
        ("🥱", "Tiring", .gray)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 12)

                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 48, height: 48)
                            .overlay(Circle().strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
                        Text("🦉")
                            .font(.system(size: 26))
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("BUNNY DEBRIEF")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.8))
                            .kerning(1.5)
                        Text("How was the mission?")
                            .font(.system(size: 18, weight: .black, design: .serif))
                            .foregroundColor(.white)
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
                                    .font(.system(size: 10, weight: .black, design: .monospaced))
                                    .foregroundColor(mood.color)
                                    .kerning(0.5)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(mood.color.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(mood.color.opacity(0.3), lineWidth: 1))
                        }
                    }
                }
                .padding(.horizontal, 24)

                Button {
                    onDismiss()
                } label: {
                    Text("Skip for now")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color(red: 0.08, green: 0.09, blue: 0.1).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
