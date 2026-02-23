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
    @EnvironmentObject var owlPolice: OwlPolice

    var onRollOut: () -> Void
    var postRideInfo: PostRideInfo?
    var pendingMoodSave: ((String) -> Void)?

    @State private var showGarage = false
    @State private var showHistory = false
    @State private var showMoodCard = false
    @State private var showProfile = false
    @State private var toastVisible = false
    @State private var topSuggestion: SavedRoute? = nil

    @State private var hasCheckedIn = false
    @State private var isTracking = true
    
    var timeOfDayGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 4..<12:  return "Morning light is breaking."
        case 12..<17: return "The afternoon sun is warm."
        case 17..<20: return "Golden hour on the asphalt."
        default:      return "The night is quiet and cool."
        }
    }
    
    var timeOfDayIcon: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 4..<12:  return "sunrise.fill"
        case 12..<17: return "sun.max.fill"
        case 17..<20: return "sunset.fill"
        default:      return "moon.stars.fill"
        }
    }
    
    var timeOfDayColor: Color {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 4..<12:  return .yellow
        case 12..<17: return .orange
        case 17..<20: return Color(red: 1.0, green: 0.4, blue: 0.2) // Deep orange/red
        default:      return .cyan
        }
    }

    var body: some View {
        ZStack {
            // MARK: Full-screen interactive map
            ZenMapView(routeState: .constant(.search), isTracking: $isTracking)
                .edgesIgnoringSafeArea(.all)
                // Interactive — no allowsHitTesting(false)

            // MARK: HUD Overlays
            VStack(spacing: 0) {
                // Top row: Basecamp Header
                BasecampHeader(
                    greeting: timeOfDayGreeting,
                    icon: timeOfDayIcon,
                    iconColor: timeOfDayColor,
                    hasCheckedIn: hasCheckedIn,
                    onCheckIn: {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                            hasCheckedIn = true
                        }
                    },
                    onOpenGarage: { showGarage = true },
                    onOpenSettings: { showProfile = true }
                )
                .padding(.top, 50)
                
                // Floating search bar (only show if checked in or as a secondary action)
                if hasCheckedIn {
                    FloatingSearchBarButton(onTap: onRollOut)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .zIndex(10)
            .allowsHitTesting(true)

            // MARK: Bottom Quick Routes Panel
            if hasCheckedIn {
                VStack {
                    Spacer()
                    QuickRoutesPanel(
                        topSuggestion: topSuggestion,
                        onRollOut: onRollOut,
                        savedRoutes: savedRoutes,
                        showHistory: $showHistory
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(8)
            }

            // MARK: Post-ride toast
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
        .onAppear {
            refreshSuggestion()
            // Show post-ride toast if info present
            if postRideInfo != nil {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                    toastVisible = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    withAnimation(.easeOut(duration: 0.5)) { toastVisible = false }
                }
                // Show mood card after toast dismisses
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    if pendingMoodSave != nil {
                        withAnimation { showMoodCard = true }
                    }
                }
            }
        }
        .onChange(of: savedRoutes.routes.count) { _ in refreshSuggestion() }
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

    private func refreshSuggestion() {
        let hour = Calendar.current.component(.hour, from: Date())
        guard hour >= 5 && hour <= 23 else { topSuggestion = nil; return }
        topSuggestion = SmartSuggestionService.suggestions(from: savedRoutes).first
    }
}

// MARK: - Basecamp Header

private struct BasecampHeader: View {
    let greeting: String
    let icon: String
    let iconColor: Color
    let hasCheckedIn: Bool
    let onCheckIn: () -> Void
    let onOpenGarage: () -> Void
    let onOpenSettings: () -> Void
    
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var driveStore: DriveStore
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: icon)
                            .foregroundColor(iconColor)
                            .font(.system(size: 14, weight: .bold))
                        Text("Camp Today")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                            .textCase(.uppercase)
                    }
                    
                    Text(hasCheckedIn ? "Ready to roll." : greeting)
                        .font(.system(size: 22, weight: .black, design: .serif))
                        .foregroundColor(.white)
                    
                    if hasCheckedIn {
                        StatsMiniHUD()
                            .padding(.top, 6)
                            .transition(.opacity)
                    }
                }
                
                Spacer()
                
                HStack(spacing: 8) {
                    if hasCheckedIn {
                        Button(action: onOpenSettings) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 36, height: 36)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    
                    VehicleHUDButton(onTap: onOpenGarage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
            
            if !hasCheckedIn {
                Button(action: onCheckIn) {
                    HStack {
                        Image(systemName: "sun.max.fill")
                            .foregroundColor(.yellow)
                        Text("Good Morning, Camp")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(white: 0.15))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                            )
                    )
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                // The Owl Guide appears after check in
                HStack(spacing: 12) {
                    Text("🦉")
                        .font(.system(size: 24))
                        .padding(8)
                        .background(Color.orange.opacity(0.2))
                        .clipShape(Circle())
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Officer Owl")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("Tire pressure checked? The road awaits.")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.8), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - Vehicle HUD Button

private struct VehicleHUDButton: View {
    let onTap: () -> Void
    @EnvironmentObject var vehicleStore: VehicleStore

    @State private var glowPulse = false

    var accentColor: Color {
        Color(hex: vehicleStore.selectedVehicle?.colorHex ?? "007AFF")
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: vehicleStore.selectedVehicle?.type.icon ?? "car.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(accentColor)

                if let vehicle = vehicleStore.selectedVehicle {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(vehicle.name)
                            .font(.system(size: 12, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(vehicle.type.displayName)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(accentColor.opacity(0.8))
                            .kerning(0.5)
                    }
                } else {
                    Text("Garage")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                ZStack {
                    Color(red: 0.08, green: 0.08, blue: 0.12)
                    LinearGradient(
                        colors: [accentColor.opacity(0.25), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        LinearGradient(
                            colors: [accentColor.opacity(glowPulse ? 0.8 : 0.4), accentColor.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: accentColor.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Stats Mini HUD

private struct StatsMiniHUD: View {
    @EnvironmentObject var driveStore: DriveStore

    var body: some View {
        if driveStore.totalRideCount > 0 {
            HStack(spacing: 8) {
                // Streak flame
                if driveStore.currentStreak > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                        Text("\(driveStore.currentStreak)")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Rectangle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 1, height: 14)
                }

                HStack(spacing: 3) {
                    Image(systemName: "flag.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("\(driveStore.totalRideCount)")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }

                Rectangle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 1, height: 14)

                HStack(spacing: 3) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.orange)
                    Text(String(format: "%.0f mi", driveStore.totalDistanceMiles))
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Color(red: 0.08, green: 0.08, blue: 0.12)
                    .overlay(Color.white.opacity(0.05))
            )
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - Floating Search Bar Button

private struct FloatingSearchBarButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Search destination")
                    .font(.system(size: 17))
                    .foregroundColor(.secondary)
                Spacer()
                Image(systemName: "mic.fill")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quick Routes Panel

private struct QuickRoutesPanel: View {
    let topSuggestion: SavedRoute?
    let onRollOut: () -> Void
    let savedRoutes: SavedRoutesStore
    @Binding var showHistory: Bool
    @EnvironmentObject var driveStore: DriveStore

    private var recentRoutes: [SavedRoute] { savedRoutes.topRecent(limit: 3) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Header row
            HStack {
                Text("QUICK ROUTES")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.white.opacity(0.5))
                    .kerning(1.5)

                Spacer()

                if driveStore.totalRideCount > 0 {
                    Button {
                        showHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 10, weight: .bold))
                            Text("History")
                                .font(.system(size: 11, weight: .bold))
                        }
                        .foregroundColor(.cyan.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Suggestion chip
            if let top = topSuggestion {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onRollOut()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        NotificationCenter.default.post(name: .zenRideNavigateTo, object: top)
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.yellow)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(SmartSuggestionService.promptText(for: top))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text(top.destinationName)
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Spacer()
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.yellow.opacity(0.7))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.yellow.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.yellow.opacity(0.3), lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            // Recent routes (horizontal chips)
            if !recentRoutes.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(recentRoutes) { route in
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                onRollOut()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                    NotificationCenter.default.post(name: .zenRideNavigateTo, object: route)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.blue)
                                    Text(route.destinationName)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.08))
                                .clipShape(Capsule())
                                .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 12)
            }

            // Start Riding button
            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onRollOut()
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Start Riding")
                        .font(.system(size: 17, weight: .black, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.cyan, Color(red: 0.0, green: 0.65, blue: 0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .shadow(color: Color.cyan.opacity(0.4), radius: 12, x: 0, y: 5)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.1)
                LinearGradient(colors: [Color.white.opacity(0.08), .clear], startPoint: .top, endPoint: .bottom)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 24, x: 0, y: -8)
        .padding(.horizontal, 0)
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Post-Ride Toast

private struct PostRideToast: View {
    let info: PostRideInfo

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.green)

            VStack(alignment: .leading, spacing: 2) {
                Text("Ride saved")
                    .font(.system(size: 14, weight: .black))
                    .foregroundColor(.white)
                HStack(spacing: 8) {
                    Text(String(format: "%.1f mi", info.distanceMiles))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                    if info.zenScore > 0 {
                        Text("· \(info.zenScore) Zen")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.cyan.opacity(0.8))
                    }
                    if info.moneySaved > 0 {
                        Text("· $\(Int(info.moneySaved)) saved")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green.opacity(0.8))
                    }
                }
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Color(red: 0.06, green: 0.12, blue: 0.1)
                Color.green.opacity(0.12)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
        .shadow(color: Color.green.opacity(0.2), radius: 10, x: 0, y: 4)
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
                Text("🦉")
                    .font(.system(size: 32))
                    .padding(10)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Officer Owl")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.orange)
                    Text("How did today feel?")
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
                            Text(mood.label)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(mood.color)
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

