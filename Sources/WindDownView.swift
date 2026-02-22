import SwiftUI

struct WindDownView: View {
    let ticketsAvoided: Int
    var onComplete: (String) -> Void
    
    @State private var dismissCountdown = 10
    @State private var timer: Timer? = nil
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)
            
            VStack(spacing: 12) {
                Text("Engine Off.")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                if ticketsAvoided > 0 {
                    Text("Officer Owl kept you safe.\nYou saved $\(ticketsAvoided * 100) today.")
                        .font(.title3)
                        .foregroundColor(.green)
                        .multilineTextAlignment(.center)
                } else {
                    Text("A quiet, peaceful ride.")
                        .font(.title3)
                        .foregroundColor(.gray)
                }
            }
            
            VStack(spacing: 20) {
                Text("How did the cruise feel?")
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.9))
                
                HStack(spacing: 16) {
                    MoodButton(symbol: "wind", color: .cyan, title: "Breezy") {
                        timer?.invalidate()
                        onComplete("Breezy")
                    }
                    MoodButton(symbol: "eye.fill", color: .orange, title: "Focused") {
                        timer?.invalidate()
                        onComplete("Focused")
                    }
                    MoodButton(symbol: "cloud.heavyrain.fill", color: .blue, title: "Heavy") {
                        timer?.invalidate()
                        onComplete("Heavy")
                    }
                }
                .padding(.horizontal)
            }
            .padding(.top, 40)
            
            Spacer()
            
            Text("Skipping in \(dismissCountdown)s...")
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
        .background(
            LinearGradient(
                colors: [.black, Color(white: 0.1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }
    
    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if dismissCountdown > 1 {
                dismissCountdown -= 1
            } else {
                timer?.invalidate()
                onComplete("Focused") // Default mood
            }
        }
    }
}

struct MoodButton: View {
    let symbol: String
    let color: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: symbol)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(.regularMaterial)
            .cornerRadius(20)
        }
    }
}
