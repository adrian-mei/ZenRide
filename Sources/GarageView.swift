import SwiftUI

struct GarageView: View {
    @EnvironmentObject var journal: RideJournal
    var onRollOut: () -> Void

    var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 4..<12: return "Good morning."
        case 12..<17: return "Good afternoon."
        case 17..<20: return "Golden hour."
        default: return "Good evening."
        }
    }
    
    var lastMood: String {
        journal.entries.first?.mood ?? "Peaceful"
    }
    
    var body: some View {
        ZStack {
            // Live map in the background
            ZenMapView(routeState: .constant(.search))
                .edgesIgnoringSafeArea(.all)
                .allowsHitTesting(false)
            
            // Heavy blur over the map
            Color.black.opacity(0.4)
                .background(.ultraThinMaterial)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 30) {
                Spacer()
                
                Image(systemName: "applelogo")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                    .padding(.bottom, 10)
                
                VStack(spacing: 8) {
                    Text("ZenRide Maps")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(greeting)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        
                    if !journal.entries.isEmpty {
                        Text("Your last ride was \(lastMood.lowercased()).")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 4)
                    }
                }
                
                VStack(spacing: 20) {
                    Text("Ride Archive")
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.8))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 4)
                    
                    HStack(spacing: 16) {
                        ArchiveStatBox(title: "Saved", value: "$\(journal.totalSaved)", icon: "leaf.fill", color: .green)
                        ArchiveStatBox(title: "Rides", value: "\(journal.entries.count)", icon: "car.fill", color: .blue)
                    }
                }
                .padding(24)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 20)
                .environment(\.colorScheme, .dark)
                
                Spacer()
                
                Button(action: onRollOut) {
                    Text("Open Maps")
                        .font(.title2) // Larger
                        .fontWeight(.heavy)
                        .foregroundColor(.white)
                        .padding(.vertical, 24) // Massive hit target for quick mounting
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
    }
}

struct ArchiveStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 32, weight: .bold))
            Text(value)
                .font(.title2)
                .fontWeight(.heavy)
                .foregroundColor(.white)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(white: 0.2).opacity(0.5)) // Slightly darker for contrast
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
