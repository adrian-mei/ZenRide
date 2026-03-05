import SwiftUI

struct AvoidPreferencesSheet: View {
    @EnvironmentObject var routingService: RoutingService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        VStack(alignment: .leading, spacing: 0) {
                            ACToggleRow(title: "Avoid Tolls", icon: "dollarsign.circle", isOn: $routingService.avoidTolls)
                            ACSectionDivider()
                            ACToggleRow(title: "Avoid Highways", icon: "road.lanes", isOn: $routingService.avoidHighways)
                            ACSectionDivider()
                            ACToggleRow(title: "Avoid Speed Cameras", icon: "camera.fill", isOn: $routingService.avoidSpeedCameras)
                        }
                        .acCardStyle(padding: 0)

                        Spacer(minLength: 20)

                        Button("Apply Options") {
                            Task { await routingService.recalculate() }
                            dismiss()
                        }
                        .buttonStyle(ACButtonStyle(variant: .primary))
                    }
                    .padding(24)
                }
            }
            .navigationTitle("Route Options")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Task { await routingService.recalculate() }
                        dismiss()
                    }
                        .foregroundColor(Theme.Colors.acWood)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
            }
        }
    }
}
