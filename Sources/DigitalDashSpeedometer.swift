import SwiftUI

struct DigitalDashSpeedometer: View {
    @ObservedObject var owlPolice: OwlPolice

    @State private var pulseScale: CGFloat = 1.0
    @State private var dangerPulse = false

    // MARK: - Computed

    var speedLimit: Double { Double(owlPolice.nearestCamera?.speed_limit_mph ?? 45) }

    var currentSpeedColor: Color {
        let s = owlPolice.currentSpeedMPH
        if s > speedLimit + 10 { return .red }
        if s > speedLimit      { return .orange }
        return .cyan
    }

    /// Gradient transitions continuously through the speed zones — no abrupt jumps.
    var ringGradient: LinearGradient {
        let s = owlPolice.currentSpeedMPH
        if s > speedLimit + 10 {
            return LinearGradient(colors: [.orange, .red], startPoint: .bottomLeading, endPoint: .topTrailing)
        } else if s > speedLimit {
            return LinearGradient(colors: [.cyan, .orange], startPoint: .bottomLeading, endPoint: .topTrailing)
        } else if isPerfectPace {
            return LinearGradient(colors: [.cyan, .green], startPoint: .bottomLeading, endPoint: .topTrailing)
        } else {
            return LinearGradient(colors: [Color.cyan.opacity(0.55), .cyan], startPoint: .bottomLeading, endPoint: .topTrailing)
        }
    }

    var speedRatio: Double { min(max(owlPolice.currentSpeedMPH / 120.0, 0.0), 1.0) }

    var isPerfectPace: Bool {
        owlPolice.currentSpeedMPH > 10 && abs(owlPolice.currentSpeedMPH - speedLimit) <= 2.0
    }

    /// True when speed exceeds limit by more than 5 mph — triggers red danger halo.
    var isDanger: Bool { owlPolice.currentSpeedMPH > speedLimit + 5 }

    /// Delta vs. speed limit. Nil while stationary or within ±1 mph.
    var speedDelta: Int? {
        guard owlPolice.currentSpeedMPH > 10 else { return nil }
        let delta = Int(owlPolice.currentSpeedMPH.rounded()) - Int(speedLimit)
        return abs(delta) > 1 ? delta : nil
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            Circle()
                .fill(Color(red: 0.05, green: 0.05, blue: 0.1).opacity(0.85))
                .shadow(color: .cyan.opacity(0.2), radius: 10)

            // Danger pulse halo — expands and fades rhythmically when speeding
            Circle()
                .stroke(Color.red.opacity(dangerPulse ? 0.45 : 0.0), lineWidth: 2.5)
                .scaleEffect(dangerPulse ? 1.09 : 1.0)
                .animation(.easeInOut(duration: 0.55).repeatForever(autoreverses: true), value: dangerPulse)

            // Full arc track — faint white ghost showing the whole range
            Circle()
                .trim(from: 0.0, to: 0.75)
                .stroke(Color.white.opacity(0.05), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(135))
                .padding(4)

            // Outer border ring
            Circle()
                .stroke(Color.gray.opacity(0.25), lineWidth: 4)
                .padding(4)

            // Gradient speed ring
            Circle()
                .trim(from: 0.0, to: CGFloat(speedRatio * 0.75))
                .stroke(ringGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(135))
                .padding(4)
                .shadow(
                    color: currentSpeedColor.opacity(0.65),
                    radius: isPerfectPace ? 16 * pulseScale : 7
                )
                .scaleEffect(isPerfectPace ? pulseScale : 1.0)

            // Center readout
            VStack(spacing: -4) {
                Text("\(Int(owlPolice.currentSpeedMPH))")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .monospacedDigit()
                    .foregroundColor(currentSpeedColor)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: Int(owlPolice.currentSpeedMPH))

                Text("MPH")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.bottom, 2)

                // Speed limit badge
                HStack(spacing: 2) {
                    Text("LIMIT")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.gray)
                    Text("\(owlPolice.nearestCamera?.speed_limit_mph ?? 45)")
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.red.opacity(0.8), in: Capsule())

                // Speed delta vs. limit — "+8" in red or "−3" in green
                if let delta = speedDelta {
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundColor(delta > 0 ? .red : .green)
                        .padding(.top, 3)
                        .transition(.scale.combined(with: .opacity))
                } else if isPerfectPace {
                    Text("ZEN")
                        .font(.system(size: 8, weight: .black))
                        .foregroundColor(.green)
                        .kerning(1)
                        .padding(.top, 3)
                        .transition(.opacity)
                }

                // Anticipation arrow (approaching camera above limit)
                if owlPolice.currentZone == .safe,
                   let nearest = owlPolice.nearestCamera,
                   owlPolice.distanceToNearestFT > 500 && owlPolice.distanceToNearestFT < 3000,
                   owlPolice.currentSpeedMPH > Double(nearest.speed_limit_mph) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.orange)
                        .padding(.top, 2)
                        .transition(.scale)
                }
            }
        }
        .frame(width: 120, height: 120)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: owlPolice.currentSpeedMPH)
        .animation(.easeInOut(duration: 0.35), value: isDanger)
        .onChange(of: isPerfectPace) { isPerfect in
            if isPerfect {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.05
                }
            } else {
                withAnimation(.easeInOut(duration: 0.5)) { pulseScale = 1.0 }
            }
        }
        .onChange(of: isDanger) { danger in
            if danger {
                dangerPulse = true
            } else {
                withAnimation(.easeInOut(duration: 0.3)) { dangerPulse = false }
            }
        }
    }
}
