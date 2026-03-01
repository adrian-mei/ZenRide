import SwiftUI
import CoreImage.CIFilterBuiltins

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var driveStore: DriveStore
    
    @State private var email = "rider@zenride.app"
    @State private var name = "Zen Rider"
    @State private var subscription = "Pro Rider"
    
    @State private var showGarage = false
    @State private var showDriveHistory = false
    @State private var showExperiences = false
    @State private var showPrivacyAlert = false
    @State private var showSignOutAlert = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // User Header
                    UserHeaderView(name: name, email: email, subscription: subscription)
                        .padding(.horizontal)
                        .padding(.top, 16)

                    // Bike Cards Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Garage")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acTextDark)
                            Spacer()
                            Button("Manage") { showGarage = true }
                                .font(.subheadline.bold())
                                .foregroundColor(Theme.Colors.acLeaf)
                        }
                        .padding(.horizontal)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(vehicleStore.vehicles) { vehicle in
                                    Button { showGarage = true } label: { BikePassCard(vehicle: vehicle) }
                                        .buttonStyle(.plain)
                                }
                                Button { showGarage = true } label: { AddBikeCard() }
                                    .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                    }

                    // Settings List
                    VStack(spacing: 0) {
                        NavigationLink(destination: VoiceSettingsView()) {
                            SettingsRow(icon: "speaker.wave.2.fill", title: "Voice Settings", color: Theme.Colors.acSky)
                        }
                        ACSectionDivider(leadingInset: 50)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showExperiences = true
                        } label: {
                            SettingsRow(icon: "star.fill", title: "San Francisco Experiences", color: Theme.Colors.acWood)
                        }
                        ACSectionDivider(leadingInset: 50)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showDriveHistory = true
                        } label: {
                            SettingsRow(icon: "clock.arrow.circlepath", title: "Drive History", color: Theme.Colors.acLeaf)
                        }
                        ACSectionDivider(leadingInset: 50)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            SettingsRow(icon: "bell.badge.fill", title: "Notifications", color: Theme.Colors.acCoral)
                        }
                        ACSectionDivider(leadingInset: 50)
                        Button {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            showPrivacyAlert = true
                        } label: {
                            SettingsRow(icon: "lock.fill", title: "Privacy", color: Theme.Colors.acWood)
                        }
                    }
                    .acCardStyle(padding: 0)
                    .padding(.horizontal)
                    .buttonStyle(.plain)

                    // Sign out
                    Button {
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        showSignOutAlert = true
                    } label: {
                        Text("Sign Out")
                            .font(.body.bold())
                            .foregroundColor(Theme.Colors.acCoral)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .acCardStyle()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("NookPhone Profile")
            .navigationBarTitleDisplayMode(.inline)
            .background(Theme.Colors.acField.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.body.bold())
                        .foregroundColor(Theme.Colors.acLeaf)
                }
            }
            .sheet(isPresented: $showGarage) { VehicleGarageView() }
            .sheet(isPresented: $showDriveHistory) {
                DriveHistoryView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showExperiences) {
                ExperiencesCatalogView { route in
                    // In a profile view context, we might just dismiss or we could inject it
                    // For now, selecting it from the profile could just dismiss the catalog.
                    // Typically, you'd navigate back to the map and load it.
                    dismiss()
                }
            }
            .alert("Privacy", isPresented: $showPrivacyAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("FashodaMap stores all your data privately on this device. Nothing is sent to external servers. Your routes, trips, and preferences never leave your iPhone.")
            }
            .alert("Sign Out", isPresented: $showSignOutAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset App Data", role: .destructive) {
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.hasCompletedOnboarding)
                    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.questsV2)
                    UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                    dismiss()
                }
            } message: {
                Text("Your data is stored locally on this device. 'Reset App Data' will clear your saved quests and restart onboarding on next launch.")
            }
            .preferredColorScheme(.light)
        }
    }
}

// MARK: - Subviews

struct UserHeaderView: View {
    let name: String
    let email: String
    let subscription: String
    @EnvironmentObject var driveStore: DriveStore
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Theme.Colors.acCream)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 2))
                Text("🦊")
                    .font(.system(size: 40))
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Villager \(name)")
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acTextDark)
                
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.acTextMuted)
                
                HStack {
                    ACBadge(
                        text: "Camp Resident",
                        textColor: Theme.Colors.acTextDark,
                        backgroundColor: Theme.Colors.acCream,
                        icon: "leaf.fill"
                    )

                    Text("\(driveStore.totalRideCount) Trips · \(Int(driveStore.totalDistanceMiles)) mi")
                        .font(.caption)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                .padding(.top, 2)
            }
            Spacer()
        }
        .acCardStyle()
    }
}

struct BikePassCard: View {
    let vehicle: Vehicle
    
    var body: some View {
        VStack(alignment: .leading) {
            // Header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.name)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Text(vehicle.licensePlate.isEmpty ? vehicle.type.displayName : vehicle.licensePlate)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 36, height: 36)
                    Image(systemName: vehicle.type.icon)
                        .foregroundColor(.white)
                }
            }
            
            Spacer()
            
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LICENSE PLATE")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.6))
                    Text(vehicle.licensePlate.isEmpty ? "UNREGISTERED" : vehicle.licensePlate.uppercased())
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                // QR Code
                Image(uiImage: generateQRCode(from: vehicle.id.uuidString))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 50, height: 50)
                    .cornerRadius(6)
                    .padding(4)
                    .background(Color.white)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(
            ZStack {
                LinearGradient(
                    colors: [Color(hex: vehicle.colorHex).opacity(0.8), Color(hex: vehicle.colorHex).opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Color.black.opacity(0.1)
            }
        )
        .cornerRadius(20)
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.Colors.acBorder, lineWidth: 2))
        .shadow(color: Color(hex: vehicle.colorHex).opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    private func generateQRCode(from string: String) -> UIImage {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage {
            if let cgimg = context.createCGImage(outputImage, from: outputImage.extent) {
                return UIImage(cgImage: cgimg)
            }
        }

        return UIImage(systemName: "qrcode") ?? UIImage()
    }
}

struct AddBikeCard: View {
    var body: some View {
        VStack {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 32))
                .foregroundColor(Theme.Colors.acLeaf)
            Text("Add Bike")
                .font(Theme.Typography.button)
                .foregroundColor(Theme.Colors.acTextDark)
                .padding(.top, 8)
        }
        .frame(width: 140, height: 160)
        .background(Theme.Colors.acCream)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(Theme.Colors.acBorder)
        )
    }
}

struct SettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .foregroundColor(.white)
                    .font(.system(size: 14, weight: .semibold))
            }
            
            Text(title)
                .font(.body)
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.system(size: 14, weight: .semibold))
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
    }
}
