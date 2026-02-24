import SwiftUI

struct RouteSelectionSheet: View {
    let destinationName: String
    var onDrive: () -> Void
    var onSimulate: () -> Void
    var onCancel: () -> Void

    @EnvironmentObject var routingService: RoutingService
    @State private var showAvoidSheet = false

    var body: some View {
        VStack(spacing: 0) {
            // MARK: Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROUTE TO")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                        .kerning(1)
                    Text(destinationName.isEmpty ? "Destination" : destinationName)
                        .font(.title2.weight(.bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer()
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 12)

            // MARK: Vehicle mode + Avoid row
            HStack(spacing: 10) {
                vehicleModeToggle
                Spacer()
                Button { showAvoidSheet = true } label: {
                    HStack(spacing: 4) {
                        Text("Avoid")
                            .font(.system(size: 14, weight: .medium))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.regularMaterial)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 14)

            // MARK: Route Options
            VStack(spacing: 10) {
                if routingService.isCalculatingRoute {
                    routeLoadingState
                } else if routingService.availableRoutes.isEmpty {
                    routeErrorState
                } else {
                    ForEach(Array(routingService.availableRoutes.enumerated()), id: \.element.id) { index, route in
                        AppleMapsRouteRow(
                            route: route,
                            isSelected: routingService.selectedRouteIndex == index,
                            onGo: onDrive,
                            onSelect: {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                routingService.selectRoute(at: index)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        ))
                    }

                    // Simulate link
                    Button(action: onSimulate) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.circle")
                            Text("Simulate")
                        }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routingService.isCalculatingRoute)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routingService.availableRoutes.count)
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .sheet(isPresented: $showAvoidSheet) {
            AvoidPreferencesSheet(
                avoidCameras: $routingService.avoidSpeedCameras,
                avoidTolls: $routingService.avoidTolls,
                avoidHighways: $routingService.avoidHighways
            )
            .presentationDetents([.height(240)])
        }
        .presentationDragIndicator(.visible)
        .onChange(of: routingService.avoidSpeedCameras) { _ in recalculatePreferences() }
        .onChange(of: routingService.avoidHighways)     { _ in recalculatePreferences() }
        .onChange(of: routingService.avoidTolls)        { _ in recalculatePreferences() }
    }

    // MARK: - Vehicle Mode Toggle

    private var vehicleModeToggle: some View {
        HStack(spacing: 2) {
            ForEach(VehicleMode.allCases, id: \.rawValue) { mode in
                Button {
                    guard routingService.vehicleMode != mode else { return }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    routingService.vehicleMode = mode
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 16, weight: routingService.vehicleMode == mode ? .bold : .regular))
                        .foregroundColor(routingService.vehicleMode == mode ? .black : .primary)
                        .frame(width: 44, height: 36)
                        .background(routingService.vehicleMode == mode ? Color.cyan : .clear)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
        .padding(3)
        .background(Color(.systemGray5))
        .clipShape(RoundedRectangle(cornerRadius: 13))
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: routingService.vehicleMode)
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

    // MARK: - Preferences

    private func recalculatePreferences() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task { await routingService.recalculate() }
    }
}

// MARK: - Apple Maps Route Row

private struct AppleMapsRouteRow: View {
    @EnvironmentObject var routingService: RoutingService
    let route: TomTomRoute
    let isSelected: Bool
    var onGo: () -> Void
    var onSelect: () -> Void

    var formattedTime: String {
        let m = route.summary.travelTimeInSeconds / 60
        let h = m / 60
        let mins = m % 60
        return h > 0 ? "\(h)h \(mins)m" : "\(m) min"
    }

    var etaString: String {
        let eta = Date().addingTimeInterval(TimeInterval(route.summary.travelTimeInSeconds))
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f.string(from: eta)
    }

    var formattedDistance: String {
        String(format: "%.1f mi", Double(route.summary.lengthInMeters) / 1609.34)
    }

    var subtitle: String {
        var parts: [String] = []
        if route.isZeroCameras {
            parts.append("Zero cameras · Safest")
        } else if route.cameraCount > 0 {
            parts.append("\(route.cameraCount) camera\(route.cameraCount == 1 ? "" : "s")")
            parts.append(route.isLessTraffic ? "Less traffic" : "Fastest")
        } else {
            parts.append(route.isLessTraffic ? "Less traffic" : "Fastest")
        }
        return parts.joined(separator: " · ")
    }

    var subtitleColor: Color {
        route.isZeroCameras ? .green : route.cameraCount > 0 ? .orange : .secondary
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(formattedTime)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                    Text("\(etaString) ETA · \(formattedDistance)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(subtitleColor)
                }
                Spacer()
                Button(action: onGo) {
                    Text("GO")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color(red: 0.2, green: 0.78, blue: 0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color.cyan.opacity(0.5) : .clear, lineWidth: 1.5)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Avoid Preferences Sheet

private struct AvoidPreferencesSheet: View {
    @Binding var avoidCameras: Bool
    @Binding var avoidTolls: Bool
    @Binding var avoidHighways: Bool

    var body: some View {
        VStack(spacing: 0) {
            Text("Avoid")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)

            VStack(spacing: 0) {
                Toggle("Speed Cameras", isOn: $avoidCameras)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                Divider().padding(.leading, 20)
                Toggle("Tolls", isOn: $avoidTolls)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
                Divider().padding(.leading, 20)
                Toggle("Highways", isOn: $avoidHighways)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 13)
            }
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)

            Spacer()
        }
    }
}

// MARK: - Helpers (RoundedCorner used by AlertOverlayView)

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
