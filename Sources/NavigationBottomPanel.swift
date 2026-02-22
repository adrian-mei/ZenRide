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
        formatter.timeStyle = .short
        let arriveDate = Date().addingTimeInterval(TimeInterval(remainingTimeSeconds))
        return formatter.string(from: arriveDate)
    }
    
    var formattedDistance: String {
        let miles = remainingDistanceMeters / 1609.34
        return String(format: "%.1f mi", miles)
    }
    
    var formattedTime: String {
        let minutes = remainingTimeSeconds / 60
        return "\(max(1, minutes)) min" // Minimum 1 min
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Drag indicator
            Capsule()
                .fill(Color.secondary.opacity(0.5))
                .frame(width: 36, height: 5)
                .padding(.top, 8)
            
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(arrivalTime)
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.3)) // Apple Maps ETA green
                    
                    HStack(spacing: 6) {
                        Text(formattedTime)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        Text("•")
                            .font(.title3)
                            .foregroundColor(.secondary)
                        Text(formattedDistance)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                Button(action: onEnd) {
                    Text("End")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
    }
}
