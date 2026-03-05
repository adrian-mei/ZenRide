import SwiftUI

struct AlertOverlayView: View {
    let camera: SpeedCamera?

    @State private var bounce = false

    var body: some View {
        if let camera = camera {
            HStack(spacing: 16) {
                // Modern Speed Limit Sign
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Colors.acCream)
                        .frame(width: 50, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.acCoral, lineWidth: 3)
                        )

                    VStack(spacing: -2) {
                        Text("SPEED\nLIMIT")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .padding(.top, 4)

                        Text("\(camera.speed_limit_mph)")
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .padding(.bottom, 2)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed Camera Ahead")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acCream)

                    Text("Reduce your speed.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acCream.opacity(0.9))
                }
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(Theme.Colors.acGold)
                    .scaleEffect(bounce ? 1.2 : 1.0)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Theme.Colors.acCoral)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(Theme.Colors.acCream, lineWidth: 3)
            )
            .shadow(color: Theme.Colors.acTextDark.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 12)
            .padding(.top, 120) // Push it down below the GuidanceView banner
            .frame(maxWidth: .infinity)
            .transition(.scale(scale: 0.9).combined(with: .opacity).combined(with: .move(edge: .top)))
            .onAppear {
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5, blendDuration: 0).repeatForever(autoreverses: true)) {
                    bounce = true
                }
            }
        }
    }
}
