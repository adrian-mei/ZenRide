import SwiftUI

struct RouteSelectionSheet: View {
    let destinationName: String
    var onDrive: () -> Void
    var onSimulate: () -> Void
    var onCancel: () -> Void

    @EnvironmentObject var routingService: RoutingService
    @State private var showAvoidSheet = false

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
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
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
                HStack(spacing: 10) {
                    vehicleModeToggle
                    Spacer()
                    Button {
                        showAvoidSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "slider.horizontal.3")
                            Text("Options")
                        }
                        .font(Theme.Typography.button)
                        .foregroundColor(Theme.Colors.acTextDark)
                    }
                    .buttonStyle(ACButtonStyle(variant: .secondary))
                    .frame(height: 36)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

                // MARK: Route List
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(Array(routingService.availableRoutes.enumerated()), id: \.offset) { index, route in
                            RouteOptionCard(
                                route: route,
                                isSelected: index == routingService.selectedRouteIndex,
                                index: index
                            )
                            .onTapGesture {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    routingService.selectRoute(at: index)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                }

                // MARK: Action Buttons
                HStack(spacing: 16) {
                    Button("Simulate") {
                        onSimulate()
                    }
                    .buttonStyle(ACButtonStyle(variant: .secondary))

                    Button("Start Drive") {
                        onDrive()
                    }
                    .buttonStyle(ACButtonStyle(variant: .primary))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
        .background(Theme.Colors.acField)
        .cornerRadius(32, corners: [.topLeft, .topRight])
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: -5)
        .sheet(isPresented: $showAvoidSheet) {
            AvoidPreferencesSheet()
        }
    }

    private var vehicleModeToggle: some View {
        HStack(spacing: 0) {
            ForEach([VehicleMode.car, VehicleMode.motorcycle], id: \.self) { mode in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        routingService.vehicleMode = mode
                    }
                } label: {
                    Image(systemName: mode == .car ? "car.fill" : "bicycle")
                        .font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 36)
                        .background(routingService.vehicleMode == mode ? Theme.Colors.acLeaf : Theme.Colors.acCream)
                        .foregroundColor(routingService.vehicleMode == mode ? .white : Theme.Colors.acTextMuted)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.acBorder, lineWidth: 2))
    }
}

// MARK: - Route Option Card
private struct RouteOptionCard: View {
    let route: TomTomRoute
    let isSelected: Bool
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(formatTime(seconds: route.summary.travelTimeInSeconds))
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                Spacer()
                
                if route.isSafeRoute {
                    Image(systemName: "shield.fill")
                        .foregroundColor(Theme.Colors.acSky)
                }
                if route.hasTolls {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundColor(Theme.Colors.acGold)
                }
                if route.isZeroCameras {
                    Image(systemName: "eye.slash.fill")
                        .foregroundColor(Theme.Colors.acLeaf)
                }
            }
            
            Text(formatDistance(meters: route.summary.lengthInMeters))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
            
            HStack(spacing: 6) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Theme.Colors.acLeaf)
                    Text("Selected")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acLeaf)
                } else {
                    Text("Route \(index + 1)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
            }
        }
        .frame(width: 140)
        .padding(16)
        .background(isSelected ? Theme.Colors.acCream : Theme.Colors.acField)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: isSelected ? Theme.Colors.acBorder : .clear, radius: 0, x: 0, y: isSelected ? 4 : 0)
        .offset(y: isSelected ? -4 : 0)
    }

    private func formatTime(seconds: Int) -> String {
        let min = seconds / 60
        if min < 60 { return "\(min) min" }
        return "\(min / 60)h \(min % 60)m"
    }

    private func formatDistance(meters: Int) -> String {
        let miles = Double(meters) * 0.000621371
        return String(format: "%.1f mi", miles)
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
                            ToggleRow(title: "Avoid Tolls", icon: "dollarsign.circle", isOn: $routingService.avoidTolls)
                            Divider().background(Theme.Colors.acBorder.opacity(0.3)).padding(.leading, 40)
                            ToggleRow(title: "Avoid Highways", icon: "road.lanes", isOn: $routingService.avoidHighways)
                            Divider().background(Theme.Colors.acBorder.opacity(0.3)).padding(.leading, 40)
                            ToggleRow(title: "Avoid Speed Cameras", icon: "camera.fill", isOn: $routingService.avoidSpeedCameras)
                        }
                        .acCardStyle(padding: 0)
                        
                        Spacer(minLength: 20)
                        
                        Button("Apply Options") {
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
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.Colors.acWood)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
    }
}

private struct ToggleRow: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundColor(Theme.Colors.acWood)
                    .frame(width: 24)
                Text(title)
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark)
            }
        }
        .tint(Theme.Colors.acLeaf)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

// Helper to round specific corners
extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape( RoundedCorner(radius: radius, corners: corners) )
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
