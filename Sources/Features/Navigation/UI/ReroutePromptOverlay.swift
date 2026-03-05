import SwiftUI

struct ReroutePromptOverlay: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider

    var body: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(Color(hex: "007AFF")) // Navigation Blue

                Text("Rerouting!")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundColor(.white)

                Text("We are calculating a new route for you. Do you want to stick with your current route filters (e.g. avoid tolls, highways)?")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(Color.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                VStack(spacing: 12) {
                    Button(action: dismiss) {
                        Text("Stick to Filters")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(hex: "007AFF"))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }

                    Button(action: removeFiltersAndRecalculate) {
                        Text("Remove Filters")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.white.opacity(0.15))
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                    }
                }
                .padding(.top, 10)
            }
            .padding(24)
            .background(Color(hex: "1C1C1E"))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
            .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 8)
            .padding(32)
        }
    }

    private func dismiss() {
        withAnimation {
            routingService.showReroutePrompt = false
        }
    }

    private func removeFiltersAndRecalculate() {
        routingService.avoidTolls = false
        routingService.avoidHighways = false
        routingService.avoidSpeedCameras = false

        dismiss()

        Task {
            await routingService.recalculate()
        }
    }
}
