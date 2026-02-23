import SwiftUI

private let arrivalFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

struct NavigationBottomPanel: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var owlPolice: OwlPolice
    var onEnd: () -> Void

    @State private var arrivingPulse = false
    @State private var showEndConfirm = false

    var remainingTimeSeconds: Int {
        let progress = owlPolice.distanceTraveledInSimulationMeters / Double(max(1, routingService.routeDistanceMeters))
        let remaining = Double(routingService.routeTimeSeconds) * (1.0 - progress)
        return max(0, Int(remaining))
    }

    var remainingDistanceMeters: Double {
        max(0, Double(routingService.routeDistanceMeters) - owlPolice.distanceTraveledInSimulationMeters)
    }

    var isArriving: Bool { remainingDistanceMeters < 320 }

    var arrivalTime: String {
        arrivalFormatter.string(from: Date().addingTimeInterval(TimeInterval(remainingTimeSeconds)))
    }

    var formattedDistance: String {
        let miles = remainingDistanceMeters / 1609.34
        if remainingDistanceMeters < 1609 { return "\(Int(remainingDistanceMeters))m" }
        return String(format: "%.1f mi", miles)
    }

    var formattedTime: String {
        if isArriving { return "Arriving" }
        if remainingTimeSeconds < 60 { return "< 1 min" }
        return "\(remainingTimeSeconds / 60) min"
    }

    var etaColor: Color { isArriving ? .green : Color(red: 0.1, green: 0.8, blue: 0.3) }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.secondary.opacity(0.4))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 10)

            // ETA row
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(isArriving ? "Arriving…" : arrivalTime)
                            .font(.system(size: isArriving ? 30 : 36, weight: .heavy, design: .monospaced))
                            .foregroundColor(isArriving ? .green : etaColor)
                            .opacity(isArriving ? (arrivingPulse ? 1.0 : 0.6) : 1.0)
                            .contentTransition(.numericText())
                        if !isArriving {
                            Text("ETA")
                                .font(.system(size: 15, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                        }
                    }

                    HStack(spacing: 6) {
                        if !isArriving {
                            Text(formattedTime)
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.primary)
                                .contentTransition(.numericText())
                            Text("•")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.secondary)
                        }
                        Text(formattedDistance)
                            .font(.system(size: 20, weight: .medium, design: .monospaced))
                            .foregroundColor(isArriving ? .green : .secondary)
                            .contentTransition(.numericText())
                    }
                }

                Spacer()

                // End Ride — large tap target, confirmation required
                Button {
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    showEndConfirm = true
                } label: {
                    Text("End")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 88, height: 64)
                        .background(Color.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .shadow(color: .red.opacity(0.45), radius: 10, x: 0, y: 4)
                }
                .confirmationDialog("End this ride?", isPresented: $showEndConfirm, titleVisibility: .visible) {
                    Button("End Ride", role: .destructive) { onEnd() }
                    Button("Cancel", role: .cancel) {}
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, isArriving ? 20 : 12)

            // Pit stops (hidden when arriving)
            if !isArriving {
                Divider().opacity(0.3).padding(.horizontal, 20)

                HStack(spacing: 0) {
                    PitStopButton(icon: "fuelpump.fill",       title: "Gas",    color: .orange)
                    PitStopButton(icon: "cup.and.saucer.fill", title: "Coffee", color: Color(red: 0.6, green: 0.35, blue: 0.1))
                    PitStopButton(icon: "fork.knife",          title: "Food",   color: .green)
                }
                .padding(.top, 6)
                .padding(.bottom, 18)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(LinearGradient(colors: [Color.cyan.opacity(0.6), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
                )
                .shadow(color: Color.cyan.opacity(0.15), radius: 20, x: 0, y: -5)
        )
        .ignoresSafeArea(edges: .bottom)
        .onChange(of: isArriving) { arriving in
            if arriving {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                    arrivingPulse = true
                }
            } else {
                arrivingPulse = false
            }
        }
    }
}

// MARK: - Pit Stop Button — 64pt circle, glove-friendly

struct PitStopButton: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.18))
                        .frame(width: 64, height: 64)
                        .overlay(Circle().strokeBorder(color.opacity(0.5), lineWidth: 1.5))

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.7), radius: 5)
                }

                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
}
