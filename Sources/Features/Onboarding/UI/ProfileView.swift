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
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // User Header
                    UserHeaderView(name: name, email: email, subscription: subscription, driveStore: driveStore)
                        .padding(.horizontal)
                        .padding(.top, 16)
                    
                    // Bike Cards Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Garage")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acTextDark)
                            Spacer()
                            Button("Manage") {
                                showGarage = true
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(Theme.Colors.acLeaf)
                        }
                        .padding(.horizontal)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(vehicleStore.vehicles) { vehicle in
                                    Button {
                                        showGarage = true
                                    } label: {
                                        BikePassCard(vehicle: vehicle)
                                    }
                                    .buttonStyle(.plain)
                                }
                                
                                Button {
                                    showGarage = true
                                } label: {
                                    AddBikeCard()
                                }
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
                        Divider().padding(.leading, 50)
                        Button(action: {}) {
                            SettingsRow(icon: "bell.badge.fill", title: "Notifications", color: Theme.Colors.acCoral)
                        }
                        Divider().padding(.leading, 50)
                        Button(action: {}) {
                            SettingsRow(icon: "lock.fill", title: "Privacy", color: Theme.Colors.acWood)
                        }
                    }
                    .acCardStyle(padding: 0)
                    .padding(.horizontal)
                    .buttonStyle(.plain)
                    
                    // Sign out
                    Button(action: {}) {
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
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundColor(Theme.Colors.acLeaf)
                }
            }
            .sheet(isPresented: $showGarage) {
                VehicleGarageView()
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
    @ObservedObject var driveStore: DriveStore
    
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
                    HStack {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(Theme.Colors.acLeaf)
                        Text("Camp Resident")
                            .font(.caption.bold())
                            .foregroundColor(Theme.Colors.acTextDark)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.Colors.acCream)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Theme.Colors.acBorder, lineWidth: 1))
                    
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
                    Text("\(vehicle.year) \(vehicle.make) \(vehicle.model)")
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
