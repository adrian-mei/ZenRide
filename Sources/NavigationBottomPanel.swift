import SwiftUI

struct NavigationBottomPanel: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var owlPolice: OwlPolice
    var onEnd: () -> Void
    
    var remainingTimeSeconds: Int {
        // Simple mock of remaining time decreasing as we drive
        let progress = owlPolice.distanceTraveledInSimulationMeters / Double(max(1, routingService.routeDistanceMeters))
        let remaining = Double(routingService.routeTimeSeconds) * (1.0 - progress)
        return max(0, Int(remaining))
    }
    
    var remainingDistanceMeters: Double {
        return max(0, Double(routingService.routeDistanceMeters) - owlPolice.distanceTraveledInSimulationMeters)
    }
    
    var arrivalTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let arriveDate = Date().addingTimeInterval(TimeInterval(remainingTimeSeconds))
        return formatter.string(from: arriveDate)
    }
    
    var formattedDistance: String {
        let miles = remainingDistanceMeters / 1609.34
        return String(format: "%.1f mi", miles)
    }
    
    var formattedTime: String {
        if remainingTimeSeconds <= 10 { return "Arriving" }
        if remainingTimeSeconds < 60  { return "< 1 min" }
        let minutes = remainingTimeSeconds / 60
        return "\(minutes) min"
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 12)
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    // Apple Maps standard layout: ETA on top, time and distance underneath
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(arrivalTime)
                            .font(.system(size: 38, weight: .heavy, design: .rounded)) // Classic heavy rounded font
                            .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.3)) // Apple Maps ETA green
                        Text("ETA")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                        Text(formattedTime)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("•")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.secondary)
                        Text(formattedDistance)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    onEnd()
                }) {
                    Text("End")
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(width: 80, height: 56) // Fixed width for standard rounded rectangle
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .accessibilityLabel("End Route")
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(UIColor.secondarySystemBackground).opacity(0.95))
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        )
        // Draw edge-to-edge on bottom without external padding
        .ignoresSafeArea(edges: .bottom)
    }
}
