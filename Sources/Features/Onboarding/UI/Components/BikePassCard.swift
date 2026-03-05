import SwiftUI
import CoreImage.CIFilterBuiltins

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
