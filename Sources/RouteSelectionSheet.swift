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
            // Header
            VStack(alignment: .leading, spacing: 8) {
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
                    }
                }
                
                // Transportation Mode Picker Placeholder
                HStack(spacing: 0) {
                    ModeButton(icon: "car.fill", isSelected: false)
                    ModeButton(icon: "figure.outdoor.cycle", isSelected: true)
                    ModeButton(icon: "figure.walk", isSelected: false)
                    ModeButton(icon: "bus.fill", isSelected: false)
                    ModeButton(icon: "bicycle", isSelected: false)
                }
                .background(.regularMaterial)
                .cornerRadius(10)
                .padding(.top, 8)
            }
            .padding(.top, 24)
            .padding(.horizontal, 24)
            .padding(.bottom, 20)
            
            // Route Options List
            VStack(spacing: 12) {
                if routingService.isCalculatingRoute {
                    HStack { Spacer(); ProgressView("Calculating routes..."); Spacer() }
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
            .padding(.bottom, 24)
            
            // Actions
            HStack(spacing: 16) {
                Button(action: {
                    timer?.invalidate()
                    onSimulate()
                }) {
                    Text("Simulate")
                        .font(.headline)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                }
                
                Button(action: {
                    timer?.invalidate()
                    onDrive()
                }) {
                    Text(countdown > 0 ? "Drive (\(countdown)s)" : "Drive")
                        .font(.title3)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .presentationDragIndicator(.visible)
        .onAppear {
            if !routingService.availableRoutes.isEmpty {
                startTimer()
            }
        }
        .onChange(of: routingService.availableRoutes.count) { count in
            if count > 0 && timer == nil {
                startTimer()
            }
        }
        .onDisappear {
            timer?.invalidate()
        }
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
            .padding()
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .background(.regularMaterial)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
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

struct ModeButton: View {
    let icon: String
    let isSelected: Bool
    
    var body: some View {
        Button(action: {}) {
            Image(systemName: icon)
                .font(.body.weight(isSelected ? .bold : .regular))
                .foregroundColor(isSelected ? .white : .primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(isSelected ? Color.blue : Color.clear)
                .cornerRadius(8)
                .padding(2)
                .opacity(isSelected ? 1.0 : 0.3) // Visually indicate they are inactive/coming soon
        }
        .disabled(!isSelected) // Actually disable them
    }
}
