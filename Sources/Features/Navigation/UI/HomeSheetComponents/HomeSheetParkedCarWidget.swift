import SwiftUI
import CoreLocation

struct HomeSheetParkedCarWidget: View {
    let car: ParkedCar
    let distanceString: String?
    let onClear: () -> Void
    let onNavigate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Parked Vehicle")
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                Image(systemName: "parkingsign.circle.fill")
                    .foregroundColor(Theme.Colors.acSky)
                    .font(.title3)
                Spacer()

                Button("Clear") {
                    onClear()
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acCoral)
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acSky.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "car.fill")
                        .font(.system(size: 22))
                        .foregroundColor(Theme.Colors.acSky)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let street = car.streetName, !street.isEmpty {
                        Text(street)
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextDark)
                    } else {
                        Text("Location Saved")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextDark)
                    }

                    if let distanceString = distanceString {
                        Text(distanceString)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.acWood)
                    }
                }
                Spacer()

                Button {
                    onNavigate()
                } label: {
                    Image(systemName: "location.fill")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Theme.Colors.acSky)
                        .clipShape(Circle())
                }
            }
            .acCardStyle(padding: 16)
            .padding(.horizontal)
        }
        .transition(.scale.combined(with: .opacity))
    }
}
