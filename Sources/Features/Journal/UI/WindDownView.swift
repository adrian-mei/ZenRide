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

    var moneySaved: Double {
        let fromEvents = cameraZoneEvents.reduce(0) { $0 + $1.moneySaved }
        // Fall back to legacy count if no granular events recorded
        return fromEvents > 0 ? fromEvents : Double(ticketsAvoided * 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                Spacer(minLength: 40)

                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.cyan)
                    .shadow(color: .cyan.opacity(0.5), radius: 10)

                VStack(spacing: 12) {
                    Text("Kickstand Down.")
                        .font(.largeTitle)
                        .fontWeight(.black)
                        .foregroundColor(.white)

                    if moneySaved > 0 {
                        Text("Officer Bunny had your back.\nEvaded $\(Int(moneySaved)) in theoretical fines.")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.cyan)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Clean run. No traps triggered.")
                            .font(.title3)
                            .foregroundColor(.gray)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .foregroundColor(zenScore > 80 ? .green : (zenScore > 50 ? .orange : .red))
                        Text("Zen Smoothness: \(zenScore)%")
                            .font(.headline)
                            .foregroundColor(zenScore > 80 ? .green : (zenScore > 50 ? .orange : .red))
                    }
                    .padding(.top, 8)
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

                // Camera zone breakdown (only shown when events were recorded)
                if !cameraZoneEvents.isEmpty {
                    CameraBreakdownCard(events: cameraZoneEvents)
                        .padding(.horizontal)
                }

                VStack(spacing: 20) {
                    HStack(spacing: 12) {
                        Text("🦉")
                            .font(.system(size: 24))
                            .padding(8)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Circle())
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Officer Bunny")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(.orange)
                            Text("How did today feel?")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.9))
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    HStack(spacing: 16) {
                        MoodButton(symbol: "leaf.fill", color: .cyan, title: "Peaceful") {
                            timer?.invalidate()
                            onComplete("Peaceful")
                        }
                        MoodButton(symbol: "flame.fill", color: .orange, title: "Adventurous") {
                            timer?.invalidate()
                            onComplete("Adventurous")
                        }
                        MoodButton(symbol: "moon.zzz.fill", color: .gray, title: "Tiring") {
                            timer?.invalidate()
                            onComplete("Tiring")
                        }
                    }
                    .padding(.horizontal)
                }
                .onTapGesture {
                    // Tapping mood area pauses auto-dismiss
                    timerPaused = true
                    timer?.invalidate()
                    withAnimation { dismissCountdown = 0 }
                }

                Group {
                    if dismissCountdown > 0 {
                        Text("Skipping in \(dismissCountdown)s...")
                            .transition(.opacity)
                    } else {
                        Text("Tap a mood to save your ride")
                            .transition(.opacity)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.gray)
                .padding(.bottom, 40)
                .animation(.easeInOut(duration: 0.25), value: dismissCountdown == 0)
            }
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
                guard !timerPaused else { return }
                if dismissCountdown > 1 {
                    dismissCountdown -= 1
                } else {
                    timer?.invalidate()
                    UINotificationFeedbackGenerator().notificationOccurred(.warning)
                    onComplete("Focused")
                }
            }
        }
    }
}

// MARK: - Camera Breakdown Card

struct CameraBreakdownCard: View {
    let events: [CameraZoneEvent]

    var totalSaved: Double { events.reduce(0) { $0 + $1.moneySaved } }
    var savedCount: Int { events.filter { $0.outcome == .saved }.count }
    var ticketCount: Int { events.filter { $0.outcome == .potentialTicket }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Camera Zones")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

            ForEach(Array(events.enumerated()), id: \.element.id) { idx, event in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Outcome icon
                        Image(systemName: event.outcome == .saved ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(event.outcome == .saved ? .green : .orange)
                            .frame(width: 24)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.cameraStreet)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            Text("\(event.speedLimitMph) mph zone  ·  entered at \(Int(event.userSpeedAtZone.rounded())) mph")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
                        }

                        Spacer()

                        if event.outcome == .saved {
                            Text("$100")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        } else {
                            Text("⚠️")
                                .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if idx < events.count - 1 {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }

            // Totals footer
            Divider()
            HStack {
                Text("Net saved this ride")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
                Text("$\(Int(totalSaved))")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(totalSaved > 0 ? .green : .white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(.regularMaterial)
        .cornerRadius(16)
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Mood Button

struct MoodButton: View {
    let symbol: String
    let color: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(color)
                    .shadow(color: color.opacity(0.5), radius: 6)
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 100) // glove-friendly minimum height
            .background(.regularMaterial)
            .cornerRadius(22)
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(color.opacity(0.3), lineWidth: 1)
            )
        }
    }
}
