import SwiftUI
import CoreLocation

struct OnboardingView: View {
    var onComplete: () -> Void

    @State private var currentPage = 0

    private let gradient = LinearGradient(
        colors: [.black, Color(white: 0.08)],
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(onNext: { currentPage = 1 })
                .tag(0)
            HowItWorksPage(onNext: { currentPage = 2 })
                .tag(1)
            LocationPermissionPage(onComplete: onComplete)
                .tag(2)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(gradient.ignoresSafeArea())
    }
}

// MARK: - Page 0: Welcome

private struct WelcomePage: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "shield.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            VStack(spacing: 12) {
                Text("ZenRide")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)

                Text("Ride smarter. Stay calm.")
                    .font(.title3)
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: onNext) {
                Text("Get Started →")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(colors: [.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Page 1: How It Works

private struct HowItWorksPage: View {
    var onNext: () -> Void

    var body: some View {
        VStack(spacing: 40) {
            Spacer()

            Text("How It Works")
                .font(.largeTitle)
                .fontWeight(.heavy)
                .foregroundColor(.white)

            VStack(spacing: 24) {
                FeatureRow(icon: "shield.fill", color: .blue,
                           title: "Camera Awareness",
                           subtitle: "Live alerts before you reach a speed trap")
                FeatureRow(icon: "map.fill", color: .green,
                           title: "Smarter Routes",
                           subtitle: "Routes calculated to keep you safe")
                FeatureRow(icon: "brain.head.profile", color: .purple,
                           title: "Learns Your Patterns",
                           subtitle: "Suggests routes at the right time of day")
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onNext) {
                Text("Next →")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(colors: [.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundColor(color)
                .frame(width: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.gray)
            }

            Spacer()
        }
    }
}

// MARK: - Page 2: Location Permission

private struct LocationPermissionPage: View {
    var onComplete: () -> Void

    @State private var locationManager = CLLocationManager()

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "location.circle.fill")
                .font(.system(size: 72))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Text("Your location, your privacy")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text("Used only while the app is open. Never in the background. Never shared.")
                    .font(.body)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
            }

            Spacer()

            VStack(spacing: 16) {
                Button(action: requestLocationAndComplete) {
                    Text("Enable Location")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 40)

                Button(action: {
                    UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
                    onComplete()
                }) {
                    Text("Skip for now")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            .padding(.bottom, 60)
        }
        .background(
            LinearGradient(colors: [.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    private func requestLocationAndComplete() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        let status = CLLocationManager.authorizationStatus()
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            onComplete()
        } else {
            locationManager.requestWhenInUseAuthorization()
            onComplete()
        }
    }
}
