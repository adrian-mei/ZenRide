import SwiftUI

struct AlertOverlayView: View {
    let camera: SpeedCamera?

    var body: some View {
        if let camera = camera {
            HStack(spacing: 16) {
                // Modern Speed Limit Sign
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 50, height: 64)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.red, lineWidth: 3)
                        )

                    VStack(spacing: -2) {
                        Text("SPEED\nLIMIT")
                            .font(.system(size: 8, weight: .bold, design: .default))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding(.top, 4)

                        Text("\(camera.speed_limit_mph)")
                            .font(.system(size: 26, weight: .black, design: .default))
                            .foregroundColor(.black)
                            .padding(.bottom, 2)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Speed Camera Ahead")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Reduce your speed.")
                        .font(.system(size: 14, weight: .semibold, design: .default))
                        .foregroundColor(Color.white.opacity(0.8))
                }
                Spacer()

                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.yellow)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(hex: "1C1C1E").opacity(0.95))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.red.opacity(0.8), lineWidth: 2)
            )
            .shadow(color: Color.red.opacity(0.3), radius: 10, x: 0, y: 5)
            .padding(.horizontal, 12)
            .padding(.top, 120) // Push it down below the GuidanceView banner
            .frame(maxWidth: .infinity)
            // Use opacity for the transition since we're pushing it down
            .transition(.opacity)
        }
    }
}
