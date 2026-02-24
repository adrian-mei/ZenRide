import SwiftUI
import MapKit
import CoreLocation
import Combine

struct AmbientGlowView: View {
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @State private var pulse: Bool = false

    var body: some View {
        ZStack {
            Color(red: 0.0, green: 0.05, blue: 0.1).ignoresSafeArea()

            LinearGradient(colors: [glowColor, .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: glowWidth * 4)
                .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(colors: [glowColor, .clear], startPoint: .bottom, endPoint: .top)
                .frame(height: glowWidth * 4)
                .frame(maxHeight: .infinity, alignment: .bottom)

            LinearGradient(colors: [glowColor, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: glowWidth * 4)
                .frame(maxWidth: .infinity, alignment: .leading)

            LinearGradient(colors: [glowColor, .clear], startPoint: .trailing, endPoint: .leading)
                .frame(width: glowWidth * 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .edgesIgnoringSafeArea(.all)
        .opacity(owlPolice.currentZone == .danger ? (pulse ? 0.8 : 0.3) : 0.6)
        .allowsHitTesting(false)
        .onChange(of: owlPolice.currentZone) { zone in
            if zone == .danger {
                withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            } else {
                withAnimation {
                    pulse = false
                }
            }
        }
    }

    var glowColor: Color {
        switch owlPolice.currentZone {
        case .danger:   return Color(red: 0.9, green: 0.1, blue: 0.2)
        case .approach: return Color(red: 0.9, green: 0.5, blue: 0.0)
        case .safe:     return Color(red: 0.0, green: 0.5, blue: 1.0)
        }
    }

    var glowWidth: CGFloat {
        switch owlPolice.currentZone {
        case .danger:   return 60
        case .approach: return 30
        case .safe:     return 15
        }
    }
}
