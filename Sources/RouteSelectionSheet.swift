import SwiftUI
import UIKit

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
            // Header
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(destinationName.isEmpty ? "Destination" : destinationName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)

                    Spacer()

                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                            .frame(width: 44, height: 44) // glove-sized hit area
                    }
                }

                // Mode picker — motorcycle + car both active, others decorative
                HStack(spacing: 0) {
                    ForEach(VehicleMode.allCases, id: \.rawValue) { mode in
                        ModeButton(
                            icon: mode.icon,
                            label: mode.displayName,
                            isSelected: routingService.vehicleMode == mode
                        ) {
                            if routingService.vehicleMode != mode {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                routingService.vehicleMode = mode
                            }
                        }
                    }

                    // Decorative only — walk, bus, bike
                    DecorativeModeButton(icon: "figure.walk")
                    DecorativeModeButton(icon: "bus.fill")
                    DecorativeModeButton(icon: "bicycle")
                }
                .background(.regularMaterial)
                .cornerRadius(12, corners: .allCorners)

                // Route preference toggles
                HStack(spacing: 8) {
                    RoutePreferenceChip(
                        icon: "camera.fill",
                        label: "No Cameras",
                        isActive: routingService.avoidSpeedCameras,
                        activeColor: .green
                    ) { routingService.avoidSpeedCameras.toggle() }

                    RoutePreferenceChip(
                        icon: "road.lanes",
                        label: "No Highways",
                        isActive: routingService.avoidHighways,
                        activeColor: .blue
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

            // Route Options List
            VStack(spacing: 12) {
                if routingService.isCalculatingRoute {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            ProgressView()
                                .scaleEffect(1.1)
                            Text("Calculating routes…")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 24)
                    .transition(.opacity)
                } else if routingService.availableRoutes.isEmpty {
                    HStack {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundColor(.orange)
                        Text("Unable to calculate route")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                    .transition(.opacity.combined(with: .move(edge: .top)))
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
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routingService.isCalculatingRoute)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: routingService.availableRoutes.count)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)

            // Actions — large glove-friendly buttons
            HStack(spacing: 14) {
                Button(action: {
                    timer?.invalidate()
                    onSimulate()
                }) {
                    Text("Simulate")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                Button(action: {
                    timer?.invalidate()
                    onDrive()
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: routingService.vehicleMode.icon)
                            .font(.title3.weight(.bold))
                        Text(countdown > 0 ? "Ride (\(countdown)s)" : "Ride")
                            .font(.title3)
                            .fontWeight(.bold)
                            .contentTransition(.numericText())
                    }
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(
                        LinearGradient(colors: [.cyan, Color(red: 0.0, green: 0.6, blue: 0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .cyan.opacity(0.4), radius: 10, x: 0, y: 4)
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
        .onDisappear {
            timer?.invalidate()
        }
        .onChange(of: routingService.avoidSpeedCameras) { _ in recalculatePreferences() }
        .onChange(of: routingService.avoidHighways)     { _ in recalculatePreferences() }
        .onChange(of: routingService.avoidTolls)        { _ in recalculatePreferences() }
    }

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

// MARK: - Active Mode Button (motorcycle / car)

private struct ModeButton: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: isSelected ? .bold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                if isSelected {
                    Text(label)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Color.blue : Color.clear)
            .cornerRadius(10, corners: .allCorners)
            .padding(2)
        }
    }
}

// MARK: - Decorative (disabled) Mode Button

private struct DecorativeModeButton: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.body)
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .opacity(0.2)
    }
}

// MARK: - Route List Row

struct RouteListRow: View {
    let route: TomTomRoute
    let isSelected: Bool
    var onSelect: () -> Void

    var formattedTime: String {
        let minutes = route.summary.travelTimeInSeconds / 60
        return "\(minutes) min"
    }

    var formattedDistance: String {
        let miles = Double(route.summary.lengthInMeters) / 1609.34
        return String(format: "%.1f mi", miles)
    }

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        if route.isZeroCameras {
                            Label("Zero Cameras", systemImage: "checkmark.shield.fill")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        } else if route.cameraCount > 0 {
                            Label("\(route.cameraCount) Speed Cameras", systemImage: "camera.badge.ellipsis")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        } else if route.isLessTraffic {
                            Text("Less Traffic")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Fastest Route")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(isSelected ? .blue : .primary)
                        }
                    }

                    if route.isZeroCameras {
                        Text("Safest Choice")
                            .font(.caption)
                            .foregroundColor(.green)
                            .fontWeight(.medium)
                    } else if route.cameraCount > 0 {
                        Text("Risk: ~$\(route.savedFines) in potential fines")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    } else {
                        Text("Standard Route")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(formattedTime)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .green : .primary)
                    Text(formattedDistance)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 64)  // glove-friendly row height
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .background(.regularMaterial)
            .cornerRadius(14, corners: .allCorners)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
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
