import SwiftUI

struct HomeSheetQuickActions: View {
    var onParkVehicle: () -> Void
    var onMarkLocation: () -> Void
    var onReportIssue: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            ACSquareActionButton(
                icon: "parkingsign.circle.fill",
                title: "Park\nVehicle",
                color: Theme.Colors.acSky
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onParkVehicle()
            }
            
            ACSquareActionButton(
                icon: "mappin.and.ellipse",
                title: "Mark\nLocation",
                color: Theme.Colors.acCoral
            ) {
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onMarkLocation()
            }
            
            ACSquareActionButton(
                icon: "exclamationmark.bubble",
                title: "Report\nIssue",
                color: Theme.Colors.acGold
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onReportIssue()
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 40)
    }
}
