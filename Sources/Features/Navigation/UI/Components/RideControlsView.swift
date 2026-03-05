import SwiftUI

struct RideControlsView: View {
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @Binding var mapMode: MapMode
    @Binding var isTracking: Bool
    var onRecenter: () -> Void
    var onReportHazard: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Map Mode
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    mapMode = (mapMode == .turnByTurn) ? .overview : .turnByTurn
                }
            } label: {
                Image(systemName: mapMode == .turnByTurn ? "map.fill" : "location.north.fill")
                    .font(Theme.Typography.headline)
                    .frame(width: 48, height: 48)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .background(Theme.Colors.acCream)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            }

            // Audio Toggle
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                bunnyPolice.isMuted.toggle()
            } label: {
                Image(systemName: bunnyPolice.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(Theme.Typography.headline)
                    .frame(width: 48, height: 48)
                    .foregroundColor(bunnyPolice.isMuted ? Theme.Colors.acError : Theme.Colors.acTextDark)
                    .background(Theme.Colors.acCream)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            }

            // Recenter
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                isTracking = true
                onRecenter()
            } label: {
                Image(systemName: isTracking ? "location.fill" : "location")
                    .font(Theme.Typography.headline)
                    .frame(width: 48, height: 48)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .background(Theme.Colors.acCream)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            }

            // Report Hazard
            Button { 
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onReportHazard() 
            } label: {
                Image(systemName: "exclamationmark.bubble.fill")
                    .font(Theme.Typography.headline)
                    .frame(width: 48, height: 48)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .background(Theme.Colors.acCream)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.15), radius: 4, x: 0, y: 2)
            }
        }
    }
}
