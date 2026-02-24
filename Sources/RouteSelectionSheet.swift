import SwiftUI

struct RouteSelectionSheet: View {
    let destinationName: String
    var onDrive: () -> Void
    var onSimulate: () -> Void
    var onCancel: () -> Void

    @EnvironmentObject var routingService: RoutingService
    @State private var countdown = 10
    @State private var timer: Timer? = nil

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ROUTE TO")
                            .font(.system(size: 11, weight: .black, design: .rounded))
                            .foregroundColor(.cyan)
                            .kerning(1.5)
                        Text(destinationName.isEmpty ? "Destination" : destinationName)
                            .font(.system(size: 26, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }

                    Spacer()

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.5))
                            .frame(width: 44, height: 44)
                    }
                }

                // MARK: Vehicle Mode Toggle (motorcycle + car only)
                HStack(spacing: 8) {
                    ForEach(VehicleMode.allCases, id: \.rawValue) { mode in
                        Button {
                            guard routingService.vehicleMode != mode else { return }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            routingService.vehicleMode = mode
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: mode.icon)
                                    .font(.system(size: 16, weight: routingService.vehicleMode == mode ? .bold : .regular))
                                Text(mode.displayName)
                                    .font(.system(size: 14, weight: routingService.vehicleMode == mode ? .bold : .regular))
                            }
                            .foregroundColor(routingService.vehicleMode == mode ? .black : .primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                routingService.vehicleMode == mode
                                    ? Color.cyan
                                    : Color(.systemGray5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(
                                color: routingService.vehicleMode == mode ? Color.cyan.opacity(0.4) : .clear,
                                radius: 8, x: 0, y: 3
                            )
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: routingService.vehicleMode)
                    }
                }

                // MARK: Route Preference Chips
                HStack(spacing: 8) {
                    RoutePreferenceChip(
                        icon: "camera.fill",
                        label: "No Cameras",
                        isActive: routingService.avoidSpeedCameras,
                        activeColor: .green
                    ) { routingService.avoidSpeedCameras.toggle() }

                    RoutePreferenceChip(
                        icon: "road.lanes.curved.right",
                        label: "Curvy Roads",
                        isActive: routingService.avoidHighways,
                        activeColor: .purple
                    ) { routingService.avoidHighways.toggle() }

                    RoutePreferenceChip(
                        icon: "dollarsign.circle.fill",
                        label: "No Tolls",
                        isActive: routingService.avoidTolls,
                        activeColor: .orange
                    ) { routingService.avoidTolls.toggle() }
                }
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // MARK: Route Options
            VStack(spacing: 10) {
                if routingService.isCalculatingRoute {
                    routeLoadingState
                } else if routingService.availableRoutes.isEmpty {
                    routeErrorState
                } else {
                    ForEach(Array(routingService.availableRoutes.enumerated()), id: \.element.id) { index, route in
                        RouteListRow(
                            route: route,
                            isSelected: routingService.selectedRouteIndex == index,
                            onSelect: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                routingService.selectRoute(at: index)
                                resetTimer()
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    // Camera risk strip (shown when routes have cameras)
                    if routingService.availableRoutes.contains(where: { $0.cameraCount > 0 }) {
                        CameraRiskStrip(routes: routingService.availableRoutes, selectedIndex: routingService.selectedRouteIndex)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routingService.isCalculatingRoute)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routingService.availableRoutes.count)
            .padding(.horizontal, 24)
            .padding(.bottom, 16)

            // MARK: Action Buttons
            HStack(spacing: 12) {
                // Simulate button
                Button(action: {
                    timer?.invalidate()
                    onSimulate()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 16, weight: .medium))
                        Text("Simulate")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }

                // Ride button with countdown arc + prominent countdown badge
                Button(action: {
                    timer?.invalidate()
                    onDrive()
                }) {
                    ZStack {
                        HStack(spacing: 8) {
                            Image(systemName: routingService.vehicleMode.icon)
                                .font(.system(size: 16, weight: .bold))
                            Text("Ride")
                                .font(.system(size: 17, weight: .black, design: .rounded))
                        }
                        .foregroundColor(.black)

                        // Countdown number — visible in top-trailing corner
                        if !routingService.isCalculatingRoute && !routingService.availableRoutes.isEmpty {
                            VStack {
                                HStack {
                                    Spacer()
                                    ZStack {
                                        Circle()
                                            .fill(Color.black.opacity(0.3))
                                            .frame(width: 26, height: 26)
                                        
                                        Circle()
                                            .trim(from: 0, to: Double(countdown) / 10.0)
                                            .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                                            .rotationEffect(.degrees(-90))
                                            .frame(width: 26, height: 26)
                                            .animation(.linear(duration: 1.0), value: countdown)
                                        
                                        Text("\(countdown)")
                                            .font(.system(size: 11, weight: .black, design: .monospaced))
                                            .foregroundColor(.white)
                                            .contentTransition(.numericText())
                                    }
                                    .padding(.top, 6)
                                    .padding(.trailing, 8)
                                }
                                Spacer()
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(
                        LinearGradient(
                            colors: [.cyan, Color(red: 0.0, green: 0.65, blue: 0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .cyan.opacity(0.45), radius: 12, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if !routingService.availableRoutes.isEmpty { startTimer() }
        }
        .onChange(of: routingService.availableRoutes.count) { count in
            if count > 0 && timer == nil { startTimer() }
        }
        .onDisappear { timer?.invalidate() }
        .onChange(of: routingService.avoidSpeedCameras) { _ in recalculatePreferences() }
        .onChange(of: routingService.avoidHighways)     { _ in recalculatePreferences() }
        .onChange(of: routingService.avoidTolls)        { _ in recalculatePreferences() }
    }

    // MARK: - States

    private var routeLoadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(.cyan)
                .scaleEffect(1.2)
            Text("Calculating routes…")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .transition(.opacity)
    }

    private var routeErrorState: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Unable to calculate route")
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text("Check your connection and try again")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await routingService.recalculate() }
            } label: {
                Label("Try Again", systemImage: "arrow.clockwise")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.cyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.cyan.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.cyan.opacity(0.3), lineWidth: 1))
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Timer

    private func recalculatePreferences() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        timer?.invalidate()
        countdown = 10
        Task { await routingService.recalculate() }
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if countdown > 1 {
                    countdown -= 1
                } else {
                    timer?.invalidate()
                    onDrive()
                }
            }
        }
    }

    private func resetTimer() {
        countdown = 10
        startTimer()
    }
}

// MARK: - Camera Risk Strip

private struct CameraRiskStrip: View {
    let routes: [TomTomRoute]
    let selectedIndex: Int

    var selectedRoute: TomTomRoute? {
        guard selectedIndex < routes.count else { return nil }
        return routes[selectedIndex]
    }

    var maxCameras: Int { routes.map(\.cameraCount).max() ?? 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                Text("CAMERA RISK ON SELECTED ROUTE")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .kerning(0.8)
            }

            if let route = selectedRoute {
                if route.isZeroCameras {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundColor(.green)
                        Text("Zero speed cameras on this route")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.green.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.green.opacity(0.3), lineWidth: 1))
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        // Visual risk bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(height: 8)

                                Capsule()
                                    .fill(LinearGradient(
                                        colors: [.orange, .red],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(
                                        width: maxCameras > 0
                                            ? geo.size.width * Double(route.cameraCount) / Double(maxCameras)
                                            : 0,
                                        height: 8
                                    )
                                    .shadow(color: .orange.opacity(0.5), radius: 4)

                                // Camera dots
                                ForEach(0..<route.cameraCount, id: \.self) { i in
                                    let position = maxCameras > 1
                                        ? Double(i) / Double(max(1, route.cameraCount - 1))
                                        : 0.5
                                    Circle()
                                        .fill(Color.red)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: .red.opacity(0.8), radius: 3)
                                        .offset(x: geo.size.width * position - 3)
                                }
                            }
                        }
                        .frame(height: 8)

                        HStack {
                            Image(systemName: "camera.badge.ellipsis")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                            Text("\(route.cameraCount) speed camera\(route.cameraCount == 1 ? "" : "s") · ~$\(route.savedFines) potential fines")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.orange.opacity(0.25), lineWidth: 1))
                }
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: selectedIndex)
    }
}

// MARK: - Route List Row

struct RouteListRow: View {
    @EnvironmentObject var routingService: RoutingService
    let route: TomTomRoute
    let isSelected: Bool
    var onSelect: () -> Void

    var formattedTime: String {
        let minutes = route.summary.travelTimeInSeconds / 60
        let hours = minutes / 60
        let mins = minutes % 60
        return hours > 0 ? "\(hours)h \(mins)m" : "\(minutes) min"
    }

    var formattedDistance: String {
        String(format: "%.1f mi", Double(route.summary.lengthInMeters) / 1609.34)
    }

    var routeAccentColor: Color {
        if route.isZeroCameras { return .green }
        if route.cameraCount > 0 { return .orange }
        if routingService.avoidHighways { return .purple }
        return .blue
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Color indicator bar
                RoundedRectangle(cornerRadius: 3)
                    .fill(routeAccentColor)
                    .frame(width: 4, height: 44)
                    .shadow(color: routeAccentColor.opacity(0.6), radius: 4)

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if route.isZeroCameras {
                            Label("Zero Cameras", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.green)
                        } else if route.cameraCount > 0 {
                            Label("\(route.cameraCount) Camera\(route.cameraCount == 1 ? "" : "s")", systemImage: "camera.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.orange)
                        } else if routingService.avoidHighways {
                            Label("Curvy Route", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.purple)
                        } else if route.isLessTraffic {
                            Label("Less Traffic", systemImage: "car.2.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.blue)
                        } else {
                            Label("Fastest", systemImage: "bolt.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.primary)
                        }

                        if route.isZeroCameras && isSelected {
                            Text("ZEN ROUTE")
                                .font(.system(size: 9, weight: .black))
                                .foregroundColor(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }

                    Text(route.isZeroCameras
                         ? "Safest choice · camera-free"
                         : route.cameraCount > 0
                             ? "Risk: ~$\(route.savedFines) potential fines"
                             : (routingService.avoidHighways ? "Scenic & curvy" : "Standard route"))
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 3) {
                    Text(formattedTime)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(isSelected ? routeAccentColor : .primary)
                    Text(formattedDistance)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(minHeight: 64)
            .background(
                ZStack {
                    if isSelected {
                        RoundedRectangle(cornerRadius: 14)
                            .fill(routeAccentColor.opacity(0.08))
                    }
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.regularMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        isSelected ? routeAccentColor.opacity(0.5) : Color.white.opacity(0.06),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isSelected ? routeAccentColor.opacity(0.15) : .clear,
                radius: 8, x: 0, y: 3
            )
        }
    }
}

// MARK: - Route Preference Chip

struct RoutePreferenceChip: View {
    let icon: String
    let label: String
    let isActive: Bool
    let activeColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .foregroundColor(isActive ? activeColor : .secondary)
            .background(isActive ? activeColor.opacity(0.15) : Color(.systemGray5))
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(isActive ? activeColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isActive)
    }
}

// MARK: - Helpers

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
