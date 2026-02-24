import SwiftUI

private let arrivalFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "h:mm a"
    return f
}()

struct NavigationBottomPanel: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    var onEnd: () -> Void

    @State private var arrivingPulse = false
    @State private var moneySavedPulse = false
    @State private var prevMoneySaved = 0

    // MARK: - Computed

    var routeProgress: Double {
        guard routingService.routeDistanceMeters > 0 else { return 0 }
        return min(1, locationProvider.distanceTraveledInSimulationMeters / Double(routingService.routeDistanceMeters))
    }

    var remainingTimeSeconds: Int {
        let remaining = Double(routingService.routeTimeSeconds) * (1.0 - routeProgress)
        return max(0, Int(remaining))
    }

    var remainingDistanceMeters: Double {
        max(0, Double(routingService.routeDistanceMeters) - locationProvider.distanceTraveledInSimulationMeters)
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

    var liveMoneySaved: Int { bunnyPolice.camerasPassedThisRide * 100 }
    var liveZenScore: Int { bunnyPolice.zenScore }

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
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(arrivalTime)
                                .font(.system(size: 38, weight: .heavy, design: .monospaced)) // Bolder, larger
                                .foregroundColor(.white)
                                .shadow(color: .cyan.opacity(0.4), radius: 6)
                                .contentTransition(.numericText())
                            Text("ETA")
                                .font(.system(size: 14, weight: .black, design: .rounded))
                                .foregroundColor(.cyan)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.cyan.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }

                    HStack(spacing: 8) {
                        if !isArriving {
                            Text(formattedTime)
                                .font(.system(size: 20, weight: .heavy, design: .monospaced))
                                .foregroundColor(Color(red: 0.8, green: 0.9, blue: 1.0))
                                .contentTransition(.numericText())
                            Text("•")
                                .font(.system(size: 20, weight: .black))
                                .foregroundColor(.cyan.opacity(0.5))
                        }
                        Text(formattedDistance)
                            .font(.system(size: 20, weight: .heavy, design: .monospaced))
                            .foregroundColor(isArriving ? .green : Color(red: 0.7, green: 0.75, blue: 0.8))
                            .contentTransition(.numericText())
                    }
                }

                Spacer()

                // End Ride — slide to end instead of tap
                SlideToEndSlider(onEnd: onEnd)
                    .frame(width: 140, height: 60)
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
                .fill(Color(red: 0.05, green: 0.05, blue: 0.08).opacity(0.85)) // Darker, sleeker motorcycle dash look
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    isArriving ? Color.green.opacity(0.8) : Color.cyan.opacity(0.6),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2.0
                        )
                )
                .shadow(
                    color: isArriving ? Color.green.opacity(0.3) : Color.cyan.opacity(0.15),
                    radius: 30, x: 0, y: -10
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
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .black))
                .foregroundColor(color)
                .shadow(color: color.opacity(0.8), radius: 5)
            Text(value)
                .font(.system(size: 18, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)
                .contentTransition(.numericText())
                .scaleEffect(pulse ? 1.25 : 1)
            Text(label)
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color(red: 0.6, green: 0.6, blue: 0.7))
                .kerning(1.5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(red: 0.1, green: 0.1, blue: 0.15).opacity(0.9))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(color.opacity(pulse ? 0.8 : 0.2), lineWidth: 1.5)
                )
                .shadow(color: color.opacity(pulse ? 0.4 : 0.0), radius: 10)
        )
    }
}

// MARK: - Slide to End Slider

private struct SlideToEndSlider: View {
    var onEnd: () -> Void

    @State private var dragOffset: CGFloat = 0
    private let trackWidth: CGFloat = 140
    private let thumbSize: CGFloat = 52
    
    var progress: Double {
        max(0, min(1, dragOffset / (trackWidth - thumbSize)))
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background track
            Capsule()
                .fill(Color(red: 0.1, green: 0.05, blue: 0.05))
                .overlay(
                    Capsule().strokeBorder(Color.red.opacity(0.3), lineWidth: 1.5)
                )

            // Text
            Text("SLIDE TO END")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .kerning(0.8)
                .foregroundColor(.red.opacity(0.8))
                .frame(maxWidth: .infinity)
                .padding(.leading, 24)
                .opacity(1.0 - progress) // fade out as thumb moves

            // Thumb
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 1.0, green: 0.2, blue: 0.2), Color(red: 0.6, green: 0.0, blue: 0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .red.opacity(0.6), radius: 6, x: 0, y: 3)
                
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .black))
                    .foregroundColor(.white)
            }
            .frame(width: thumbSize, height: thumbSize)
            .padding(4)
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow dragging to the right
                        let x = max(0, value.translation.width)
                        dragOffset = min(x, trackWidth - thumbSize)
                    }
                    .onEnded { value in
                        if progress > 0.8 {
                            // Complete
                            withAnimation(.spring()) {
                                dragOffset = trackWidth - thumbSize
                            }
                            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onEnd()
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                dragOffset = 0
                            }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
            )
        }
        .frame(width: trackWidth, height: 60)
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
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 68, height: 68)
                        .overlay(Circle().strokeBorder(color.opacity(tapped ? 1.0 : 0.6), lineWidth: tapped ? 3.0 : 1.5))
                        .shadow(color: color.opacity(tapped ? 0.8 : 0.3), radius: 10)

                    Image(systemName: icon)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(color)
                        .shadow(color: color.opacity(0.9), radius: tapped ? 12 : 6)
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
