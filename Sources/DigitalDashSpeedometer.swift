import SwiftUI

struct DigitalDashSpeedometer: View {
    @ObservedObject var owlPolice: OwlPolice
    
    var currentSpeedColor: Color {
        let speed = owlPolice.currentSpeedMPH
        let limit = Double(owlPolice.nearestCamera?.speed_limit_mph ?? 45)
        if speed > limit + 10 {
            return .red
        } else if speed > limit {
            return .orange
        } else {
            return .cyan // Neon cyan for safe speed
        }
    }
    
    var speedRatio: Double {
        let speed = owlPolice.currentSpeedMPH
        // Assuming max display speed of 120 mph for the dial
        return min(max(speed / 120.0, 0.0), 1.0)
    }
    
    var body: some View {
        ZStack {
            // Dark Background
            Circle()
                .fill(Color(red: 0.05, green: 0.05, blue: 0.1).opacity(0.85))
                .shadow(color: .cyan.opacity(0.2), radius: 10, x: 0, y: 0)
            
            // Outer Ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 4)
                .padding(4)
                
            // Dynamic RPM/Speed Ring
            Circle()
                .trim(from: 0.0, to: CGFloat(speedRatio * 0.75)) // 0.75 leaves a gap at the bottom
                .stroke(currentSpeedColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(135)) // Start from bottom left
                .padding(4)
                .shadow(color: currentSpeedColor.opacity(0.6), radius: 6, x: 0, y: 0) // Neon Glow
            
            VStack(spacing: -4) {
                Text("\(Int(owlPolice.currentSpeedMPH))")
                    .font(.system(size: 42, weight: .black, design: .monospaced))
                    .foregroundColor(currentSpeedColor)
                    .contentTransition(.numericText())
                
                Text("MPH")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(.gray)
                    .padding(.bottom, 2)
                    
                // Speed Limit Integrated
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
                
                // Anticipation Arrow
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
    }
}
