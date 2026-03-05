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
                            .font(Theme.Typography.label)
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
                            .font(Theme.Typography.title)
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
                                .font(Theme.Typography.body)
                                .bold()
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
                            .font(Theme.Typography.title3)
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
