import SwiftUI

struct TurnByTurnHUDView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider

    var body: some View {
        VStack(spacing: 12) {
            if routingService.activeRoute.isEmpty {
                if let streetName = locationProvider.currentStreetName {
                    HStack {
                        Image(systemName: "car.fill")
                            .foregroundColor(.white)
                        Text(streetName)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(hex: "0B5B56"))
                    .clipShape(Capsule())
                    .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            } else {
                GuidanceView()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}
