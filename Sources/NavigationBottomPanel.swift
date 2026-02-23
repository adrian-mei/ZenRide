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
    @State private var moneySavedPulse = false
    @State private var prevMoneySaved = 0

    // MARK: - Computed

    var routeProgress: Double {
        guard routingService.routeDistanceMeters > 0 else { return 0 }
        return min(1, owlPolice.distanceTraveledInSimulationMeters / Double(routingService.routeDistanceMeters))
    }

    var remainingTimeSeconds: Int {
        let remaining = Double(routingService.routeTimeSeconds) * (1.0 - routeProgress)
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
        if remainingDistanceMeters < 1609 { return "\(Int(remainingDistanceMeters)) m" }
        return String(format: "%.1f mi", remainingDistanceMeters / 1609.34)
    }

    var formattedTime: String {
        if isArriving { return "Arriving" }
        if remainingTimeSeconds < 60 { return "< 1 min" }
        let h = remainingTimeSeconds / 3600
        let m = (remainingTimeSeconds % 3600) / 60
        return h > 0 ? "\(h)h \(m)m" : "\(m) min"
    }

    var liveMoneySaved: Int { owlPolice.camerasPassedThisRide * 100 }
    var liveZenScore: Int { owlPolice.zenScore }

    var body: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 10)

            // MARK: Route Progress Bar
            RouteProgressBar(progress: routeProgress, isArriving: isArriving)
                .padding(.horizontal, 24)
                .padding(.bottom, 14)

            // MARK: ETA + End Row
            HStack(alignment: .center, spacing: 16) {
                // ETA block
                VStack(alignment: .leading, spacing: 4) {
                    if isArriving {
                        Text("Arriving…")
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundColor(.green)
                            .opacity(arrivingPulse ? 1.0 : 0.55)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text(arrivalTime)
                                .font(.system(size: 32, weight: .heavy, design: .monospaced))
                                .foregroundColor(.white)
                                .contentTransition(.numericText())
                            Text("ETA")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cyan.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 6) {
                        if !isArriving {
                            Text(formattedTime)
                                .font(.system(size: 18, weight: .bold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.85))
                                .contentTransition(.numericText())
                            Text("·")
                                .foregroundColor(.white.opacity(0.3))
                        }
                        Text(formattedDistance)
                            .font(.system(size: 18, weight: .medium, design: .monospaced))
                            .foregroundColor(isArriving ? .green : .white.opacity(0.55))
                            .contentTransition(.numericText())
                    }
                }

                Spacer()

                // End Ride — single tap, no confirmation (per design plan)
                Button {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onEnd()
                } label: {
                    VStack(spacing: 3) {
                        Image(systemName: "stop.fill")
                            .font(.system(size: 18, weight: .bold))
                        Text("END")
                            .font(.system(size: 11, weight: .black))
                            .kerning(1)
                    }
                    .foregroundColor(.white)
                    .frame(width: 72, height: 64)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.9, green: 0.15, blue: 0.15), Color(red: 0.7, green: 0.1, blue: 0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .red.opacity(0.5), radius: 10, x: 0, y: 4)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, isArriving ? 0 : 10)

            // MARK: Live Metrics Row
            if !isArriving {
                HStack(spacing: 0) {
                    LiveMetricTile(
                        label: "ZEN",
                        value: "\(liveZenScore)",
                        icon: "leaf.fill",
                        color: zenColor(liveZenScore)
                    )

                    metricDivider

                    LiveMetricTile(
                        label: "SAVED",
                        value: liveMoneySaved > 0 ? "$\(liveMoneySaved)" : "–",
                        icon: "banknote.fill",
                        color: liveMoneySaved > 0 ? .green : .white.opacity(0.3),
                        pulse: moneySavedPulse
                    )

                    metricDivider

                    LiveMetricTile(
                        label: "DONE",
                        value: "\(Int(routeProgress * 100))%",
                        icon: "flag.fill",
                        color: .cyan
                    )
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            // MARK: Pit Stops
            if !isArriving {
                Divider().opacity(0.15).padding(.horizontal, 20)

                HStack(spacing: 0) {
                    PitStopButton(icon: "fuelpump.fill",       title: "Gas",    color: .orange,                  query: "Gas Stations")
                    PitStopButton(icon: "cup.and.saucer.fill", title: "Coffee", color: Color(red: 0.8, green: 0.5, blue: 0.2), query: "Coffee")
                    PitStopButton(icon: "fork.knife",          title: "Food",   color: .green,                   query: "Restaurants")
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
                        .stroke(
                            LinearGradient(
                                colors: [
                                    isArriving ? Color.green.opacity(0.7) : Color.cyan.opacity(0.5),
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(
                    color: isArriving ? Color.green.opacity(0.2) : Color.cyan.opacity(0.12),
                    radius: 24, x: 0, y: -6
                )
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
        .onChange(of: liveMoneySaved) { newVal in
            guard newVal > prevMoneySaved else { return }
            prevMoneySaved = newVal
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                moneySavedPulse = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation { moneySavedPulse = false }
            }
        }
    }

    private var metricDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(width: 1, height: 28)
    }

    private func zenColor(_ score: Int) -> Color {
        switch score {
        case 80...: return .green
        case 50...: return .yellow
        default:    return .orange
        }
    }
}

// MARK: - Route Progress Bar

private struct RouteProgressBar: View {
    let progress: Double
    let isArriving: Bool

    @State private var glowPulse = false

    var fillColor: Color { isArriving ? .green : .cyan }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 6)

                // Fill
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [fillColor, fillColor.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geo.size.width * progress, height: 6)
                    .shadow(color: fillColor.opacity(glowPulse ? 0.9 : 0.4), radius: 6, x: 0, y: 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)

                // Leading dot
                Circle()
                    .fill(fillColor)
                    .frame(width: 10, height: 10)
                    .shadow(color: fillColor.opacity(0.8), radius: 4)
                    .offset(x: max(0, geo.size.width * progress - 5))
                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
            }
            .frame(height: 10, alignment: .center)
        }
        .frame(height: 10)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }
    }
}

// MARK: - Live Metric Tile

private struct LiveMetricTile: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    var pulse: Bool = false

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .scaleEffect(pulse ? 1.15 : 1)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .kerning(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(color.opacity(pulse ? 0.15 : 0.06))
        )
    }
}

// MARK: - Pit Stop Button — 64pt, opens Apple Maps nearby

struct PitStopButton: View {
    let icon: String
    let title: String
    let color: Color
    let query: String

    @State private var tapped = false

    var body: some View {
        Button {
            UISelectionFeedbackGenerator().selectionChanged()
            openMapsSearch(query: query)
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) { tapped = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                withAnimation { tapped = false }
            }
        } label: {
            VStack(spacing: 7) {
                ZStack {
                    Circle()
                        .fill(color.opacity(tapped ? 0.3 : 0.12))
                        .frame(width: 64, height: 64)
                        .overlay(Circle().strokeBorder(color.opacity(tapped ? 0.9 : 0.4), lineWidth: 1.5))
                        .shadow(color: color.opacity(tapped ? 0.5 : 0.0), radius: 8)

                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.7), radius: tapped ? 8 : 4)
                }
                .scaleEffect(tapped ? 0.9 : 1.0)

                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func openMapsSearch(query: String) {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "maps://?q=\(encoded)&near=current") else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
}
