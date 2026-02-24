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
                                .font(.title3.bold())
                            Spacer()
                            Button("Manage") {
                                showGarage = true
                            }
                            .font(.subheadline.bold())
                            .foregroundColor(.cyan)
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
                            SettingsRow(icon: "speaker.wave.2.fill", title: "Voice Settings", color: .blue)
                        }
                        Divider().padding(.leading, 50)
                        Button(action: {}) {
                            SettingsRow(icon: "bell.badge.fill", title: "Notifications", color: .red)
                        }
                        Divider().padding(.leading, 50)
                        Button(action: {}) {
                            SettingsRow(icon: "lock.fill", title: "Privacy", color: .gray)
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)
                    .padding(.horizontal)
                    .buttonStyle(.plain)
                    
                    // Sign out
                    Button(action: {}) {
                        Text("Sign Out")
                            .font(.body.bold())
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundColor(.cyan)
                }
            }
            .sheet(isPresented: $showGarage) {
                VehicleGarageView()
            }
            .preferredColorScheme(.dark)
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
                    .fill(Color.cyan.opacity(0.15))
                    .frame(width: 72, height: 72)
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 72, height: 72)
                    .foregroundColor(.cyan)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(name)
                    .font(.title2.bold())
                    .foregroundColor(.primary)
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Text(subscription)
                        .font(.caption.bold())
                        .foregroundColor(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                    
                    Text("\(driveStore.totalRideCount) Rides · \(Int(driveStore.totalDistanceMiles)) mi")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 2)
            }
            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
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
        .frame(width: 280, height: 160)
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
                .foregroundColor(.cyan)
            Text("Add Bike")
                .font(.subheadline.bold())
                .foregroundColor(.cyan)
                .padding(.top, 8)
        }
        .frame(width: 140, height: 160)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8]))
                .foregroundColor(.cyan.opacity(0.5))
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
