import SwiftUI
import MapKit
import CoreLocation
import Combine

struct AlertOverlayView: View {
    let camera: SpeedCamera?

    var body: some View {
        if let camera = camera {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white)
                        .frame(width: 70, height: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.black, lineWidth: 3)
                        )

                    VStack(spacing: 0) {
                        Text("SPEED\nLIMIT")
                            .font(.system(size: 10, weight: .black))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.black)
                            .padding(.top, 8)

                        Text("\(camera.speed_limit_mph)")
                            .font(.system(size: 38, weight: .heavy))
                            .foregroundColor(.black)
                            .padding(.bottom, 4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("SPEED TRAP AHEAD")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.5), radius: 2)
                    Text("Roll off the throttle")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white.opacity(0.9))
                }
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 64)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
            .background(
                ZStack {
                    Color(red: 0.9, green: 0.1, blue: 0.2).opacity(0.9)
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .background(.ultraThinMaterial)
            )
            .clipShape(RoundedCorner(radius: 24, corners: [.bottomLeft, .bottomRight]))
            .shadow(color: Color(red: 0.9, green: 0.1, blue: 0.2).opacity(0.6), radius: 20, x: 0, y: 10)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
