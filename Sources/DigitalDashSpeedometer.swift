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

            // Outer border ring (thicker and stylized)
            Circle()
                .stroke(Color.gray.opacity(0.35), lineWidth: 8)
                .padding(2)

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
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: speedRatio)

            // Center readout (Larger, more aggressive font for speed)
            VStack(spacing: -8) {
                Text("\(Int(owlPolice.currentSpeedMPH))")
                    .font(.system(size: 56, weight: .heavy, design: .monospaced)) // INCREASED
                    .monospacedDigit()
                    .foregroundColor(currentSpeedColor)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: Int(owlPolice.currentSpeedMPH))
                    .shadow(color: currentSpeedColor.opacity(0.8), radius: 6)

                Text("MPH")
                    .font(.system(size: 14, weight: .black, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 6)

                // Speed limit badge (tactical styling)
                HStack(spacing: 4) {
                    Text("LIMIT")
                        .font(.system(size: 9, weight: .heavy, design: .monospaced))
                        .foregroundColor(dangerPulse ? .white : .black)
                    Text("\(owlPolice.nearestCamera?.speed_limit_mph ?? 45)")
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundColor(dangerPulse ? .white : .black)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(dangerPulse ? Color.red : Color.white, in: RoundedRectangle(cornerRadius: 4, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).strokeBorder(Color.red, lineWidth: 2))
                .animation(.easeInOut(duration: 0.5), value: dangerPulse)

                // Speed delta vs. limit — "+8" in red or "−3" in green
                if let delta = speedDelta {
                    Text(delta > 0 ? "+\(delta)" : "\(delta)")
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundColor(delta > 0 ? .red : .green)
                        .padding(.top, 4)
                        .transition(.scale.combined(with: .opacity))
                } else if isPerfectPace {
                    Text("ZEN")
                        .font(.system(size: 12, weight: .black))
                        .foregroundColor(.green)
                        .kerning(1)
                        .padding(.top, 4)
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
        .frame(width: 150, height: 150)
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
