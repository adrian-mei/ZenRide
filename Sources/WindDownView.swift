import SwiftUI

struct WindDownView: View {
    let ticketsAvoided: Int
    let rideContext: RideContext?
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

            // Route summary card
            if let ctx = rideContext {
                VStack(spacing: 6) {
                    Text(ctx.destinationName)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    HStack(spacing: 20) {
                        Label(formattedDistance(ctx), systemImage: "arrow.triangle.turn.up.right.diamond")
                        Label(formattedDuration(ctx), systemImage: "clock")
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(16)
                .background(.regularMaterial)
                .cornerRadius(16)
                .padding(.horizontal)
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
            .padding(.top, 20)

            Spacer()

            if dismissCountdown > 0 {
                Text("Skipping in \(dismissCountdown)s...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            } else {
                Text("Tap a mood to save your ride")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding(.bottom, 20)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            timer?.invalidate()
            dismissCountdown = 0
        }
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

    private func formattedDistance(_ ctx: RideContext) -> String {
        if ctx.routeDistanceMeters < 1609 {
            return "\(ctx.routeDistanceMeters)m"
        } else {
            return String(format: "%.1f mi", Double(ctx.routeDistanceMeters) / 1609.34)
        }
    }

    private func formattedDuration(_ ctx: RideContext) -> String {
        let minutes = Int((Double(ctx.routeDurationSeconds) / 60).rounded())
        return "\(minutes) min"
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                if dismissCountdown > 1 {
                    dismissCountdown -= 1
                } else {
                    timer?.invalidate()
                    onComplete("Focused") // Default mood
                }
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
