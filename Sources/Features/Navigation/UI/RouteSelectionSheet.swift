import SwiftUI

private enum RouteActiveSheet: Identifiable {
    case avoidPrefs, vehicleGarage
    var id: Self { self }
}

struct RouteSelectionSheet: View {
    let destinationName: String
    var onDrive: () -> Void
    var onSimulate: () -> Void
    var onCancel: () -> Void

    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var vehicleStore: VehicleStore
    @State private var activeSheet: RouteActiveSheet?

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // MARK: Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ROUTE TO")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .kerning(1)
                        Text(destinationName.isEmpty ? "Destination" : destinationName)
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Theme.Colors.acWood)
                            .frame(width: 44, height: 44)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 12)

                // MARK: Vehicle mode + Avoid row
                HStack(spacing: 12) {
                    Button {
                        activeSheet = .vehicleGarage
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: vehicleStore.selectedVehicleMode.icon)
                                .font(.system(size: 16, weight: .bold))
                            Text(vehicleStore.selectedVehicleMode.displayName)
                                .font(Theme.Typography.button)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.acLeaf)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Button {
                        activeSheet = .avoidPrefs
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Options")
                                .font(Theme.Typography.button)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.Colors.acCream)
                        .foregroundColor(Theme.Colors.acTextDark)
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(Theme.Colors.acBorder.opacity(0.8), lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // MARK: Route List
                VStack(spacing: 0) {
                    if routingService.isCalculatingRoute {
                        HStack(spacing: 12) {
                            ProgressView().tint(Theme.Colors.acLeaf)
                            Text("Calculating routes…")
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.acTextMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                    } else {
                        ForEach(Array(routingService.availableRoutes.enumerated()), id: \.offset) { index, route in
                            RouteListRow(route: route, isSelected: index == routingService.selectedRouteIndex) {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    routingService.selectRoute(at: index)
                                }
                            }
                            if index < routingService.availableRoutes.count - 1 {
                                Divider().background(Theme.Colors.acBorder.opacity(0.3))
                            }
                        }
                    }
                }
                .acCardStyle(padding: 0)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)

                // MARK: Action Buttons
                VStack(spacing: 12) {
                    Button(action: onDrive) {
                        Text("Start Drive")
                            .font(.system(size: 20, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ACButtonStyle(variant: .largePrimary))
                    .disabled(routingService.isCalculatingRoute || routingService.availableRoutes.isEmpty)

                    Button(action: onSimulate) {
                        Text("Simulate Route")
                            .font(Theme.Typography.button)
                    }
                    .buttonStyle(ACButtonStyle(variant: .secondary))
                    .disabled(routingService.isCalculatingRoute || routingService.availableRoutes.isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.Colors.acField)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .avoidPrefs:
                AvoidPreferencesSheet()
            case .vehicleGarage:
                VehicleGarageView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

// MARK: - Route List Row
private struct RouteListRow: View {
    let route: TomTomRoute
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder, lineWidth: 2)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Theme.Colors.acLeaf).frame(width: 12, height: 12)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(formatTime(route.summary.travelTimeInSeconds))
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        Spacer()
                        if route.isSafeRoute {
                            Image(systemName: "shield.fill")
                                .foregroundColor(Theme.Colors.acSky)
                                .font(.system(size: 13))
                        }
                        if route.isZeroCameras {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(Theme.Colors.acLeaf)
                                .font(.system(size: 13))
                        }
                        if route.hasTolls {
                            Image(systemName: "dollarsign.circle.fill")
                                .foregroundColor(Theme.Colors.acGold)
                                .font(.system(size: 13))
                        }
                    }
                    Text(formatDistance(route.summary.lengthInMeters))
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isSelected ? Theme.Colors.acLeaf.opacity(0.08) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatTime(_ seconds: Int) -> String {
        let min = seconds / 60
        return min < 60 ? "\(min) min" : "\(min / 60)h \(min % 60)m"
    }

    private func formatDistance(_ meters: Int) -> String {
        String(format: "%.1f mi", Double(meters) * 0.000621371)
    }
}

// MARK: - Avoid Preferences Sheet
private struct AvoidPreferencesSheet: View {
    @EnvironmentObject var routingService: RoutingService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 0) {
                            ACToggleRow(title: "Avoid Tolls", icon: "dollarsign.circle", isOn: $routingService.avoidTolls)
                            ACSectionDivider()
                            ACToggleRow(title: "Avoid Highways", icon: "road.lanes", isOn: $routingService.avoidHighways)
                            ACSectionDivider()
                            ACToggleRow(title: "Avoid Speed Cameras", icon: "camera.fill", isOn: $routingService.avoidSpeedCameras)
                        }
                        .acCardStyle(padding: 0)

                        Spacer(minLength: 20)

                        Button("Apply Options") {
                            Task { await routingService.recalculate() }
                            dismiss()
                        }
                        .buttonStyle(ACButtonStyle(variant: .primary))
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Route Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Task { await routingService.recalculate() }
                        dismiss()
                    }
                        .foregroundColor(Theme.Colors.acWood)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
    }
}
