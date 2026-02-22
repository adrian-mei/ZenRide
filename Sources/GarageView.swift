import SwiftUI

struct GarageView: View {
    @EnvironmentObject var journal: RideJournal
    @EnvironmentObject var savedRoutes: SavedRoutesStore
    var onRollOut: () -> Void

    @State private var suggestionAppeared = false

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

            ScrollView {
                VStack(spacing: 24) {
                    Spacer(minLength: 60)

                    // Identity
                    VStack(spacing: 8) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                            .padding(.bottom, 10)

                        Text("ZenRide")
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

                    // Suggestion chip — only when suggestions exist and it's a reasonable hour
                    let currentHour = Calendar.current.component(.hour, from: Date())
                    if let top = SmartSuggestionService.suggestions(from: savedRoutes).first,
                       currentHour >= 5 && currentHour <= 23 {
                        SuggestionChipView(route: top) {
                            onRollOut()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                NotificationCenter.default.post(name: .zenRideNavigateTo, object: top)
                            }
                        }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .padding(.horizontal, 20)
                    }

                    // Stats card
                    StatsCardView()
                        .padding(.horizontal, 20)

                    // Recent routes (only if history exists)
                    let recent = savedRoutes.topRecent(limit: 3)
                    if !recent.isEmpty {
                        RecentRoutesView(routes: recent) { route in
                            onRollOut()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                NotificationCenter.default.post(name: .zenRideNavigateTo, object: route)
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer(minLength: 20)

                    Button(action: onRollOut) {
                        Text("Open Maps")
                            .font(.title2)
                            .fontWeight(.heavy)
                            .foregroundColor(.white)
                            .padding(.vertical, 24)
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
}

// MARK: - Suggestion Chip

struct SuggestionChipView: View {
    let route: SavedRoute
    let onTap: () -> Void

    @State private var appeared = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text(SmartSuggestionService.promptText(for: route))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if let avgHour = route.typicalDepartureHours.sorted().dropFirst(route.typicalDepartureHours.count / 4).first {
                        Text("Usually around \(formattedHour(avgHour))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.yellow.opacity(0.4), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .scaleEffect(appeared ? 1 : 0.9)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                appeared = true
            }
        }
    }

    private func formattedHour(_ hour: Int) -> String {
        let period = hour < 12 ? "am" : "pm"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(h)\(period)"
    }
}

// MARK: - Stats Card

struct StatsCardView: View {
    @EnvironmentObject var journal: RideJournal

    var body: some View {
        VStack(spacing: 16) {
            Text("Ride Archive")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 12) {
                ArchiveStatBox(title: "Saved", value: "$\(journal.totalSaved)", icon: "leaf.fill", color: .green)
                ArchiveStatBox(title: "Rides", value: "\(journal.entries.count)", icon: "car.fill", color: .blue)
                ArchiveStatBox(title: "Miles", value: String(format: "%.1f", journal.totalDistanceMiles), icon: "map.fill", color: .orange)
            }
        }
        .padding(24)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .environment(\.colorScheme, .dark)
    }
}

// MARK: - Recent Routes

struct RecentRoutesView: View {
    let routes: [SavedRoute]
    let onTap: (SavedRoute) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Routes")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))

            VStack(spacing: 0) {
                ForEach(Array(routes.enumerated()), id: \.element.id) { index, route in
                    Button(action: { onTap(route) }) {
                        HStack(spacing: 12) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(.blue)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.destinationName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                Text(relativeDate(route.lastUsedDate))
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.5))
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                    }

                    if index < routes.count - 1 {
                        Divider().padding(.leading, 50)
                    }
                }
            }
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .environment(\.colorScheme, .dark)
        }
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
        switch days {
        case 0: return "Today"
        case 1: return "Yesterday"
        default: return "\(days) days ago"
        }
    }
}

// MARK: - Stat Box (kept for compatibility)

struct ArchiveStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 28, weight: .bold))
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
        .background(Color(white: 0.2).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
