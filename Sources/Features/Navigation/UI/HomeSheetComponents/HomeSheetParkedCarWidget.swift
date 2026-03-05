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
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acCoral)
            }
            .padding(.horizontal)

            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acSky.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: "car.fill")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acSky)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let street = car.streetName, !street.isEmpty {
                        Text(street)
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextDark)
                    } else {
                        Text("Location Saved")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextDark)
                    }

                    if let distanceString = distanceString {
                        Text(distanceString)
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.acWood)
                    }
                }
                Spacer()

                Button {
                    onNavigate()
                } label: {
                    Image(systemName: "location.fill")
                        .font(Theme.Typography.title3)
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
