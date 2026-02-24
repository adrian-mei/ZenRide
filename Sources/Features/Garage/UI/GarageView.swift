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
    @State private var topSuggestion: SavedRoute? = nil

    @State private var hasCheckedIn = false
    @State private var isTracking = true
    @State private var startPulse = false

    var body: some View {
        ZStack {
            // Full-screen interactive map
            ZenMapView(routeState: .constant(.search), isTracking: $isTracking)
                .edgesIgnoringSafeArea(.all)

            // Scanline overlay for game-screen feel
            GameScanlineOverlay()
                .allowsHitTesting(false)
                .zIndex(1)

            // HUD Overlays
            VStack(spacing: 0) {
                GameDashboardHeader(
                    hasCheckedIn: hasCheckedIn,
                    onCheckIn: {
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            hasCheckedIn = true
                        }
                    },
                    onOpenGarage: { showGarage = true },
                    onOpenSettings: { showProfile = true }
                )
                .padding(.top, 50)

                if hasCheckedIn {
                    // Floating mission search bar
                    MissionSearchButton(onTap: onRollOut)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                Spacer()
            }
            .zIndex(10)
            .allowsHitTesting(true)

            // Bottom Mission Panel
            if hasCheckedIn {
                VStack {
                    Spacer()
                    MissionSelectPanel(
                        topSuggestion: topSuggestion,
                        onRollOut: onRollOut,
                        savedRoutes: savedRoutes,
                        showHistory: $showHistory
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                .zIndex(8)
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
        }
        .onAppear {
            refreshSuggestion()
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                startPulse = true
            }
            // Skip check-in if returning from a ride or already an active rider
            if postRideInfo != nil || driveStore.totalRideCount > 0 {
                hasCheckedIn = true
            }
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

// MARK: - Scanline Overlay (game CRT effect)

private struct GameScanlineOverlay: View {
    var body: some View {
        GeometryReader { geo in
            LinearGradient(
                colors: [
                    Color.black.opacity(0.0),
                    Color.black.opacity(0.03),
                    Color.black.opacity(0.0),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .blendMode(.multiply)
    }
}

// MARK: - Game Dashboard Header

private struct GameDashboardHeader: View {
    let hasCheckedIn: Bool
    let onCheckIn: () -> Void
    let onOpenGarage: () -> Void
    let onOpenSettings: () -> Void

    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var driveStore: DriveStore
    @State private var enginePulse = false

    var body: some View {
        VStack(spacing: 0) {
            // Top HUD bar
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    // Game label
                    HStack(spacing: 6) {
                        Image(systemName: "dot.radiowaves.left.and.right")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(.green)
                        Text("ZENRIDE  ·  LIVE")
                            .font(.system(size: 10, weight: .black, design: .monospaced))
                            .foregroundColor(.green)
                            .kerning(2)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.green.opacity(0.15))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.green.opacity(0.4), lineWidth: 1))

                    if hasCheckedIn {
                        PlayerStatsHUD()
                            .transition(.opacity.combined(with: .move(edge: .leading)))
                    } else {
                        Text("SELECT MISSION")
                            .font(.system(size: 26, weight: .black, design: .monospaced))
                            .foregroundColor(.white)
                            .transition(.opacity)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 8) {
                    if hasCheckedIn {
                        Button(action: onOpenSettings) {
                            Image(systemName: "gearshape.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                    VehicleHUDButton(onTap: onOpenGarage)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 14)

            // Start Engine / already running
            if !hasCheckedIn {
                StartEngineButton(onTap: onCheckIn, pulse: enginePulse)
                    .padding(.horizontal, 20)
                    .transition(.scale.combined(with: .opacity))
            } else {
                // Bunny briefing — mission briefing style
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.2))
                            .frame(width: 38, height: 38)
                            .overlay(Circle().strokeBorder(Color.orange.opacity(0.4), lineWidth: 1))
                        Text("🦉")
                            .font(.system(size: 20))
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("BUNNY INTEL")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.orange.opacity(0.7))
                            .kerning(1.5)
                        Text("Systems green. Camera net active. Roll when ready.")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color.black.opacity(0.88), Color.black.opacity(0.0)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                enginePulse = true
            }
        }
    }
}

// MARK: - Start Engine Button

private struct StartEngineButton: View {
    let onTap: () -> Void
    let pulse: Bool

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(pulse ? 0.25 : 0.12))
                        .frame(width: 48, height: 48)
                        .scaleEffect(pulse ? 1.08 : 1.0)
                        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    Image(systemName: "power.circle.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.cyan)
                        .shadow(color: .cyan.opacity(0.7), radius: 8)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("START ENGINE")
                        .font(.system(size: 18, weight: .black, design: .monospaced))
                        .foregroundColor(.white)
                        .kerning(1)
                    Text("Begin today's session")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right.2")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.cyan.opacity(0.7))
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Color(red: 0.04, green: 0.08, blue: 0.12)
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.18), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.cyan.opacity(pulse ? 0.9 : 0.5), Color.cyan.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.cyan.opacity(0.3), radius: 12, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Player Stats HUD

private struct PlayerStatsHUD: View {
    @EnvironmentObject var driveStore: DriveStore

    var body: some View {
        HStack(spacing: 10) {
            if driveStore.currentStreak > 0 {
                statBadge("\(driveStore.currentStreak)", icon: "flame.fill", color: .orange, label: "STREAK")
                divider
            }
            statBadge("\(driveStore.totalRideCount)", icon: "flag.checkered", color: .cyan, label: "MISSIONS")
            if driveStore.totalDistanceMiles > 0 {
                divider
                statBadge(String(format: "%.0f", driveStore.totalDistanceMiles), icon: "road.lanes", color: .purple, label: "MI")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            ZStack {
                Color(red: 0.06, green: 0.06, blue: 0.1)
                Color.white.opacity(0.04)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func statBadge(_ value: String, icon: String, color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                Text(label)
                    .font(.system(size: 7, weight: .black, design: .monospaced))
                    .foregroundColor(color.opacity(0.7))
                    .kerning(1)
            }
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.15))
            .frame(width: 1, height: 22)
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
                        Text(vehicle.type.displayName.uppercased())
                            .font(.system(size: 8, weight: .black, design: .monospaced))
                            .foregroundColor(accentColor.opacity(0.8))
                            .kerning(0.8)
                    }
                } else {
                    Text("GARAGE")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
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

// MARK: - Mission Search Button

private struct MissionSearchButton: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                Image(systemName: "scope")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.cyan)
                Text("SET DESTINATION")
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundColor(.white.opacity(0.85))
                    .kerning(0.5)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 6, height: 6)
                    Text("READY")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(.cyan)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
            .background(
                ZStack {
                    Color(red: 0.05, green: 0.08, blue: 0.12).opacity(0.92)
                    LinearGradient(colors: [Color.cyan.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing)
                }
                .background(.regularMaterial)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.cyan.opacity(0.35), lineWidth: 1)
            )
            .shadow(color: Color.cyan.opacity(0.15), radius: 10, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mission Select Panel

private struct MissionSelectPanel: View {
    let topSuggestion: SavedRoute?
    let onRollOut: () -> Void
    let savedRoutes: SavedRoutesStore
    @Binding var showHistory: Bool
    @EnvironmentObject var driveStore: DriveStore

    private var recentRoutes: [SavedRoute] { savedRoutes.topRecent(limit: 3) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Panel handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .frame(maxWidth: .infinity)
                .padding(.top, 10)
                .padding(.bottom, 14)

            // Panel header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(.cyan)
                    Text("MISSION SELECT")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.55))
                        .kerning(1.5)
                }

                Spacer()

                if driveStore.totalRideCount > 0 {
                    Button {
                        showHistory = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 10, weight: .bold))
                            Text("ARCHIVE")
                                .font(.system(size: 10, weight: .black, design: .monospaced))
                                .kerning(0.5)
                        }
                        .foregroundColor(.cyan.opacity(0.8))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 12)

            // Suggested mission
            if let top = topSuggestion {
                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onRollOut()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        NotificationCenter.default.post(name: .zenRideNavigateTo, object: top)
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 38, height: 38)
                                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1))
                            Image(systemName: "sparkles")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.yellow)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("SUGGESTED MISSION")
                                .font(.system(size: 9, weight: .black, design: .monospaced))
                                .foregroundColor(.yellow.opacity(0.7))
                                .kerning(1)
                            Text(top.destinationName)
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text(SmartSuggestionService.promptText(for: top))
                                .font(.system(size: 11))
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.yellow.opacity(0.6))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(Color.yellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.yellow.opacity(0.25), lineWidth: 1))
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }

            // Recent missions (horizontal)
            if !recentRoutes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("LAST MISSIONS")
                        .font(.system(size: 9, weight: .black, design: .monospaced))
                        .foregroundColor(.white.opacity(0.35))
                        .kerning(1.5)
                        .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
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
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.cyan)
                                        Text(route.destinationName)
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(.white)
                                            .lineLimit(1)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        ZStack {
                                            Color.white.opacity(0.06)
                                            LinearGradient(colors: [Color.cyan.opacity(0.08), .clear], startPoint: .leading, endPoint: .trailing)
                                        }
                                    )
                                    .clipShape(Capsule())
                                    .overlay(Capsule().strokeBorder(Color.cyan.opacity(0.2), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 12)
            }

            // LAUNCH MISSION button
            Button(action: {
                UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                onRollOut()
            }) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.black.opacity(0.3))
                            .frame(width: 36, height: 36)
                        Image(systemName: "play.fill")
                            .font(.system(size: 16, weight: .black))
                            .foregroundColor(.black)
                    }

                    Text("LAUNCH MISSION")
                        .font(.system(size: 17, weight: .black, design: .monospaced))
                        .foregroundColor(.black)
                        .kerning(0.5)

                    Spacer()

                    Image(systemName: "arrow.right.circle.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.black.opacity(0.6))
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.cyan, Color(red: 0.0, green: 0.7, blue: 0.9)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: Color.cyan.opacity(0.5), radius: 14, x: 0, y: 6)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .background(
            ZStack {
                Color(red: 0.05, green: 0.05, blue: 0.08)
                LinearGradient(
                    colors: [Color.cyan.opacity(0.06), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.cyan.opacity(0.3), Color.cyan.opacity(0.05)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.5), radius: 28, x: 0, y: -10)
        .padding(.horizontal, 0)
        .ignoresSafeArea(edges: .bottom)
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
