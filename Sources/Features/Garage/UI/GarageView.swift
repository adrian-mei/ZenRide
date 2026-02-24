import SwiftUI

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
    var postRideInfo: PostRideInfo?
    var pendingMoodSave: ((String) -> Void)?

    @State private var showGarage = false
    @State private var showHistory = false
    @State private var showMoodCard = false
    @State private var showProfile = false
    @State private var toastVisible = false

    @State private var isTracking = true
    @State private var bottomSheetDetent: PresentationDetent = .fraction(0.35)
    @State private var searchText = ""

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
                searchText: $searchText,
                onProfileTap: { showProfile = true },
                onSearchTap: onRollOut,
                savedRoutes: savedRoutes
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
    @Binding var searchText: String
    var onProfileTap: () -> Void
    var onSearchTap: () -> Void
    @ObservedObject var savedRoutes: SavedRoutesStore
    
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
                
                // Search Bar + Profile
                HStack(spacing: 12) {
                    Button(action: onSearchTap) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            Text(searchText.isEmpty ? "Search Destinations" : searchText)
                                .foregroundColor(searchText.isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "mic.fill")
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    
                    Button(action: onProfileTap) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .frame(width: 36, height: 36)
                            .foregroundColor(.cyan)
                    }
                }
                .padding(.horizontal)
                
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
                            PlaceIcon(icon: "fuelpump.fill", color: .green, title: "Gas Station")
                            PlaceIcon(icon: "cup.and.saucer.fill", color: .orange, title: "Coffee")
                            PlaceIcon(icon: "parkingsign.circle.fill", color: .blue, title: "Parking")
                            PlaceIcon(icon: "wrench.and.screwdriver.fill", color: .gray, title: "Mechanic")
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Recents
                if !savedRoutes.routes.isEmpty {
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
                            ForEach(Array(savedRoutes.topRecent(limit: 3).enumerated()), id: \.element.id) { index, route in
                                RecentRow(icon: "arrow.turn.up.right", title: route.destinationName, subtitle: "From My Location")
                                if index < min(savedRoutes.routes.count, 3) - 1 {
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
        .background(Color(.systemBackground))
        .preferredColorScheme(.dark)
    }
}

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
    
    var body: some View {
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
        .background(Color(red: 0.08, green: 0.09, blue: 0.1).ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}
