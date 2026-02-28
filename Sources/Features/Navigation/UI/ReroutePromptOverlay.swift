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
                    .foregroundColor(Theme.Colors.acCoral)
                
                Text("Rerouting!")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acTextDark)
                
                Text("We are calculating a new route for you. Do you want to stick with your current route filters (e.g. avoid tolls, highways)?")
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button("Stick to Filters", action: dismiss)
                        .buttonStyle(ACButtonStyle(variant: .primary))

                    ACDangerButton(title: "Remove Filters", action: removeFiltersAndRecalculate)
                }
                .padding(.top, 10)
            }
            .padding(24)
            .background(Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 5)
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