import SwiftUI

struct AlertOverlayView: View {
    let camera: SpeedCamera?

    var body: some View {
        if let camera = camera {
            HStack(spacing: 20) {
                // Wooden Camp Sign style for Speed Limit
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Theme.Colors.acCream)
                        .frame(width: 70, height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.Colors.acBorder, lineWidth: 4)
                        )

                    VStack(spacing: 0) {
                        Text("SPEED\nLIMIT")
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundColor(Theme.Colors.acTextDark)
                            .padding(.top, 8)

                        Text("\(camera.speed_limit_mph)")
                            .font(.system(size: 38, weight: .heavy, design: .rounded))
                            .foregroundColor(Theme.Colors.acCoral)
                            .padding(.bottom, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Stop Ahead!")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                    
                    Text("Time to slow down and enjoy the view.")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(Theme.Colors.acField)
            .clipShape(RoundedCorner(radius: 32, corners: [.bottomLeft, .bottomRight]))
            .overlay(
                RoundedCorner(radius: 32, corners: [.bottomLeft, .bottomRight])
                    .stroke(Theme.Colors.acBorder, lineWidth: 2)
            )
            .shadow(color: Theme.Colors.acBorder.opacity(0.4), radius: 10, x: 0, y: 5)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
