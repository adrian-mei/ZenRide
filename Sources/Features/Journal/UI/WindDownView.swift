import SwiftUI

struct WindDownView: View {
    let ticketsAvoided: Int
    let zenScore: Int
    let rideContext: RideContext?
    let cameraZoneEvents: [CameraZoneEvent]
    var onComplete: (String) -> Void

    @State private var dismissCountdown = 10
    @State private var timer: Timer? = nil
    @State private var timerPaused = false
    @State private var selectedMood: String? = nil

    var moneySaved: Double {
        let fromEvents = cameraZoneEvents.reduce(0) { $0 + $1.moneySaved }
        // Fall back to legacy count if no granular events recorded
        return fromEvents > 0 ? fromEvents : Double(ticketsAvoided * 100)
    }

    var body: some View {
        ZStack {
            Theme.Colors.acField.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    Spacer(minLength: 40)

                    // Stamp / Badge
                    ZStack {
                        Circle()
                            .fill(Theme.Colors.acLeaf.opacity(0.15))
                            .frame(width: 120, height: 120)
                            .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 2))
                        
                        Image(systemName: "tent.fill")
                            .font(.system(size: 60))
                            .foregroundColor(Theme.Colors.acLeaf)
                    }

                    // Header
                    VStack(spacing: 12) {
                        Text("Camp Reached!")
                            .font(Theme.Typography.title)
                            .foregroundColor(Theme.Colors.acTextDark)

                        if moneySaved > 0 {
                            Text("Safe travels! You avoided $\(Int(moneySaved)) in fines.")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acWood)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        } else {
                            Text("A beautiful, safe journey.")
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acTextMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }

                    // Stats Card
                    VStack(spacing: 16) {
                        HStack {
                            ACStatBox(title: "Safety Score", value: "\(zenScore)", icon: "shield.fill", iconColor: Theme.Colors.acSky)
                            if let ctx = rideContext {
                                let miles = Double(ctx.routeDistanceMeters) * 0.000621371
                                ACStatBox(title: "Distance", value: String(format: "%.1f mi", miles), icon: "ruler.fill", iconColor: Theme.Colors.acCoral)
                                let duration = Int(Date().timeIntervalSince(ctx.departureTime))
                                ACStatBox(title: "Time", value: formatDuration(duration), icon: "clock.fill", iconColor: Theme.Colors.acGold)
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    // Journal Entry
                    VStack(alignment: .leading, spacing: 16) {
                        Text("How was the vibe?")
                            .font(Theme.Typography.headline)
                            .foregroundColor(Theme.Colors.acTextDark)
                        
                        HStack(spacing: 12) {
                            MoodButton(emoji: "☀️", label: "Sunny", isSelected: selectedMood == "Sunny") { selectMood("Sunny") }
                            MoodButton(emoji: "🌧️", label: "Moody", isSelected: selectedMood == "Moody") { selectMood("Moody") }
                            MoodButton(emoji: "🎵", label: "Singing", isSelected: selectedMood == "Singing") { selectMood("Singing") }
                            MoodButton(emoji: "☕️", label: "Cozy", isSelected: selectedMood == "Cozy") { selectMood("Cozy") }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer(minLength: 40)

                    // Auto-close button
                    Button(action: {
                        complete()
                    }) {
                        HStack {
                            Text("Close Journal")
                            if !timerPaused {
                                Text("(\(dismissCountdown))")
                                    .opacity(0.8)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ACButtonStyle(variant: .primary))
                    .padding(.horizontal, 24)
                    .padding(.bottom, 48)
                }
            }
        }
        .onAppear {
            startTimer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func selectMood(_ mood: String) {
        selectedMood = mood
        timerPaused = true
        timer?.invalidate()
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if dismissCountdown > 1 {
                dismissCountdown -= 1
            } else {
                complete()
            }
        }
    }

    private func complete() {
        timer?.invalidate()
        onComplete(selectedMood ?? "Cozy")
    }
    
    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        return "\(m / 60)h \(m % 60)m"
    }
}


private struct MoodButton: View {
    let emoji: String
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 32))
                Text(label)
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(isSelected ? Theme.Colors.acTextDark : Theme.Colors.acTextMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? Theme.Colors.acLeaf.opacity(0.2) : Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Theme.Colors.acLeaf : Theme.Colors.acBorder, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}
