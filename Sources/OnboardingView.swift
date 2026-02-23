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
            OnboardingVehiclePage(onNext: { currentPage = 3 })
                .tag(2)
            LocationPermissionPage(onComplete: onComplete)
                .tag(3)
        }
        .tabViewStyle(.page)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(gradient.ignoresSafeArea())
    }
}

// MARK: - Page 0: Welcome

private struct WelcomePage: View {
    var onNext: () -> Void
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.cyan.opacity(0.1))
                    .frame(width: 140, height: 140)
                    .blur(radius: 14)
                Image(systemName: "shield.fill")
                    .font(.system(size: 72, weight: .heavy))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.7), radius: 22)
            }
            .scaleEffect(appeared ? 1 : 0.55)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.55, dampingFraction: 0.62), value: appeared)

            VStack(spacing: 12) {
                Text("ZenRide")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(.white)

                Text("Ride smarter. Stay calm.")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.2), value: appeared)

            Spacer()

            Button(action: onNext) {
                Text("Get Started →")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color.cyan)
                    .clipShape(Capsule())
                    .shadow(color: .cyan.opacity(0.4), radius: 16, x: 0, y: 8)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 60)
            .opacity(appeared ? 1 : 0)
            .animation(.easeOut(duration: 0.4).delay(0.32), value: appeared)
        }
        .background(
            LinearGradient(colors: [.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
        .onAppear { appeared = true }
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
                FeatureRow(icon: "shield.fill", color: .cyan,
                           title: "Camera Awareness",
                           subtitle: "Live alerts before you reach a speed trap",
                           index: 0)
                FeatureRow(icon: "map.fill", color: .green,
                           title: "Smarter Routes",
                           subtitle: "Routes calculated to keep you safe",
                           index: 1)
                FeatureRow(icon: "brain.head.profile", color: .purple,
                           title: "Learns Your Patterns",
                           subtitle: "Suggests routes at the right time of day",
                           index: 2)
            }
            .padding(.horizontal, 32)

            Spacer()

            Button(action: onNext) {
                Text("Next →")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity)
                    .background(Color.cyan)
                    .clipShape(Capsule())
                    .shadow(color: .cyan.opacity(0.4), radius: 16, x: 0, y: 8)
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
    let index: Int

    @State private var appeared = false

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 52, height: 52)
                    .shadow(color: color.opacity(0.35), radius: 10)
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(color)
            }

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
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : 30)
        .animation(.spring(response: 0.45, dampingFraction: 0.72).delay(Double(index) * 0.12), value: appeared)
        .onAppear { appeared = true }
    }
}

// MARK: - Page 2: Vehicle Picker

private struct OnboardingVehiclePage: View {
    var onNext: () -> Void
    @EnvironmentObject var vehicleStore: VehicleStore

    @State private var selectedType: VehicleType = .motorcycle
    @State private var name = ""
    @State private var make = ""
    @State private var model = ""
    @State private var yearText = ""
    @State private var selectedColorHex = "00FFFF"

    private let neonColors: [(hex: String, color: Color)] = [
        ("00FFFF", .cyan),
        ("00FF7F", Color(red: 0, green: 1, blue: 0.5)),
        ("9B59B6", Color(red: 0.61, green: 0.35, blue: 0.71)),
        ("FF6B35", Color(red: 1, green: 0.42, blue: 0.21)),
        ("FF1493", Color(red: 1, green: 0.08, blue: 0.58)),
        ("007AFF", .blue),
    ]

    var isValid: Bool { !name.isEmpty && !make.isEmpty && !model.isEmpty && Int(yearText) != nil }

    var selectedNeonColor: Color {
        neonColors.first(where: { $0.hex == selectedColorHex })?.color ?? .cyan
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 48)

                VStack(spacing: 8) {
                    Text("What do you ride?")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    Text("Tell us about your vehicle")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                // Type cards
                HStack(spacing: 16) {
                    ForEach(VehicleType.allCases, id: \.self) { type in
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedType = type
                            }
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: type.icon)
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(selectedType == type ? .cyan : .white.opacity(0.35))
                                Text(type.displayName)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(selectedType == type ? .cyan : .white.opacity(0.35))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(
                                selectedType == type
                                    ? Color.cyan.opacity(0.15)
                                    : Color.white.opacity(0.05)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(
                                        selectedType == type ? Color.cyan.opacity(0.6) : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                            .shadow(color: selectedType == type ? Color.cyan.opacity(0.2) : .clear, radius: 12)
                        }
                    }
                }
                .padding(.horizontal, 32)

                // Live vehicle preview
                ZStack {
                    Circle()
                        .fill(selectedNeonColor.opacity(0.1))
                        .frame(width: 110, height: 110)
                    Circle()
                        .strokeBorder(selectedNeonColor.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 110, height: 110)
                    Image(systemName: selectedType.icon)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(selectedNeonColor)
                        .shadow(color: selectedNeonColor.opacity(0.65), radius: 12)
                }
                .shadow(color: selectedNeonColor.opacity(0.3), radius: 22, x: 0, y: 0)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedColorHex)
                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: selectedType)

                // Quick details
                VStack(spacing: 14) {
                    vehicleField("Nickname", placeholder: "e.g. Black Beast", text: $name)
                    vehicleField("Make", placeholder: "e.g. Honda", text: $make)
                    vehicleField("Model", placeholder: "e.g. CBR600RR", text: $model)
                    vehicleField("Year", placeholder: "e.g. 2021", text: $yearText, keyboard: .numberPad)
                }
                .padding(.horizontal, 32)

                // Color dots
                VStack(spacing: 10) {
                    Text("CHOOSE A COLOR")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .kerning(1.5)
                    HStack(spacing: 14) {
                        ForEach(neonColors, id: \.hex) { item in
                            Button {
                                selectedColorHex = item.hex
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(item.color)
                                        .frame(width: 38, height: 38)
                                        .shadow(color: item.color.opacity(0.7), radius: 8)
                                    if selectedColorHex == item.hex {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 14, weight: .black))
                                            .foregroundColor(.black)
                                    }
                                }
                            }
                        }
                    }
                }

                // CTA or skip
                VStack(spacing: 12) {
                    Button {
                        if isValid {
                            let vehicle = Vehicle(
                                name: name,
                                make: make,
                                model: model,
                                year: Int(yearText) ?? Calendar.current.component(.year, from: Date()),
                                type: selectedType,
                                colorHex: selectedColorHex,
                                licensePlate: "",
                                odometerMiles: 0
                            )
                            vehicleStore.addVehicle(vehicle)
                        }
                        onNext()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: selectedType == .motorcycle ? "figure.motorcycle" : "car.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(isValid ? "Next →" : "Skip for now")
                                .font(.title3)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(isValid ? Color.cyan : Color.blue)
                        .clipShape(Capsule())
                    }
                    .padding(.horizontal, 40)

                    if !isValid {
                        Text("You can add your vehicle later from the garage")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(.bottom, 60)
            }
        }
        .background(
            LinearGradient(colors: [.black, Color(white: 0.08)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }

    @ViewBuilder
    private func vehicleField(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.caption.bold())
                .foregroundColor(.gray)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.white.opacity(0.12), lineWidth: 1))
        }
    }
}

// MARK: - Page 3: Location Permission

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
