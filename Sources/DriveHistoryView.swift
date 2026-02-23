import SwiftUI

struct DriveHistoryView: View {
    @EnvironmentObject var driveStore: DriveStore
    @State private var selectedRecord: DriveRecord? = nil

    var body: some View {
        NavigationView {
            Group {
                if driveStore.records.isEmpty {
                    EmptyHistoryView()
                } else {
                    List {
                        // MARK: Streak + Stats Banner
                        Section {
                            RiderStatsBanner()
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                        .listRowSeparator(.hidden)

                        // MARK: Achievements shelf
                        Section {
                            AchievementsShelf()
                                .padding(.vertical, 4)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)

                        // MARK: Route Records
                        Section {
                            ForEach(driveStore.records.sorted(by: { $0.lastDrivenDate > $1.lastDrivenDate })) { record in
                                Button(action: { selectedRecord = record }) {
                                    RouteRecordRow(record: record)
                                }
                                .listRowBackground(Color(white: 0.1))
                                .listRowSeparatorTint(Color.white.opacity(0.1))
                            }
                        } header: {
                            Text("ROUTES")
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(.white.opacity(0.4))
                                .kerning(1.5)
                                .listRowInsets(EdgeInsets(top: 16, leading: 16, bottom: 4, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .background(Color.black)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Drive History")
            .navigationBarTitleDisplayMode(.large)
            .background(Color.black.ignoresSafeArea())
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .sheet(item: $selectedRecord) { record in
            DriveRecordDetailView(record: record)
        }
    }
}

// MARK: - Rider Stats Banner

private struct RiderStatsBanner: View {
    @EnvironmentObject var driveStore: DriveStore

    var body: some View {
        let streak = driveStore.currentStreak
        HStack(spacing: 0) {
            // Streak section
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(streak > 0 ? Color.red.opacity(0.2) : Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                    Image(systemName: "flame.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(streak > 0 ? .red : .white.opacity(0.2))
                        .shadow(color: streak > 0 ? .red.opacity(0.5) : .clear, radius: 6)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(streak > 0 ? "\(streak) day streak" : "No streak yet")
                        .font(.system(size: 15, weight: .black, design: .rounded))
                        .foregroundColor(streak > 0 ? .white : .white.opacity(0.3))
                    Text(streak > 0 ? "Keep it up!" : "Ride today to start one")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            Spacer()

            // Quick stats
            HStack(spacing: 16) {
                if driveStore.todayMiles > 0 {
                    quickStat(value: String(format: "%.1f", driveStore.todayMiles), label: "mi today", color: .cyan)
                }
                if driveStore.avgZenScore > 0 {
                    quickStat(value: "\(driveStore.avgZenScore)", label: "avg zen", color: .green)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.07, blue: 0.14), Color(red: 0.04, green: 0.04, blue: 0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func quickStat(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 16, weight: .black, design: .rounded))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
                .kerning(0.5)
        }
    }
}

// MARK: - Empty State

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "road.lanes")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.3))
            Text("No rides recorded yet")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.6))
            Text("Complete a ride to see your history here.")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

// MARK: - Route Record Row

private struct RouteRecordRow: View {
    let record: DriveRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.destinationName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text("\(record.sessionCount) \(record.sessionCount == 1 ? "drive" : "drives")  ·  Last: \(relativeDate(record.lastDrivenDate))")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.3))
                    .padding(.top, 4)
            }

            HStack(spacing: 16) {
                StatChip(icon: "speedometer", value: String(format: "%.0f mph avg", record.allTimeAvgSpeedMph), color: .cyan)
                StatChip(icon: "leaf.fill", value: "$\(Int(record.allTimeMoneySaved))", color: .green)
                StatChip(icon: "map", value: String(format: "%.1f mi", record.totalDistanceMiles), color: .orange)
            }
        }
        .padding(.vertical, 12)
    }

    private func relativeDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: date, to: Date()).day ?? 0
        switch days {
        case 0:  return "Today"
        case 1:  return "Yesterday"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}

private struct StatChip: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Drive Record Detail (all sessions for a route)

struct DriveRecordDetailView: View {
    let record: DriveRecord
    @State private var selectedSession: DriveSession? = nil

    var body: some View {
        NavigationView {
            List {
                // Aggregate header section
                Section {
                    AggregateStatsCard(record: record)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                // Sessions
                Section(header: Text("Sessions").foregroundColor(.white.opacity(0.6))) {
                    let bestId  = record.sessions.max(by: { $0.zenScore < $1.zenScore })?.id
                    let worstId = record.sessions.count > 1
                        ? record.sessions.min(by: { $0.zenScore < $1.zenScore })?.id
                        : nil
                    ForEach(record.sessions) { session in
                        let badge: String? = session.id == bestId ? "BEST"
                            : session.id == worstId ? "LOW" : nil
                        Button(action: { selectedSession = session }) {
                            SessionRow(session: session, sessionBadge: badge)
                        }
                        .listRowBackground(Color(white: 0.1))
                        .listRowSeparatorTint(Color.white.opacity(0.1))
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(record.destinationName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .sheet(item: $selectedSession) { session in
            DriveSessionDetailView(session: session)
        }
    }
}

private struct AggregateStatsCard: View {
    let record: DriveRecord

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 0) {
                AggStat(title: "Drives", value: "\(record.sessionCount)", icon: "flag.checkered", color: .cyan)
                AggStat(title: "Avg Speed", value: String(format: "%.0f mph", record.allTimeAvgSpeedMph), icon: "speedometer", color: .blue)
                AggStat(title: "Top Speed", value: String(format: "%.0f mph", record.allTimeTopSpeedMph), icon: "bolt.fill", color: .yellow)
                AggStat(title: "Saved", value: "$\(Int(record.allTimeMoneySaved))", icon: "leaf.fill", color: .green)
            }
        }
        .padding(20)
        .background(Color(white: 0.12))
    }
}

private struct AggStat: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
    }
}

private struct SessionRow: View {
    let session: DriveSession
    var sessionBadge: String? = nil   // "BEST" | "LOW" | nil

    private var timeColor: Color {
        switch session.timeOfDayCategory.label.lowercased() {
        case let s where s.contains("morning"):   return Color(red: 1.0, green: 0.75, blue: 0.2)
        case let s where s.contains("afternoon"): return .yellow
        case let s where s.contains("evening"):   return .orange
        case let s where s.contains("night"):     return .purple
        default:                                   return .blue
        }
    }

    private var timeIcon: String {
        switch session.timeOfDayCategory.label.lowercased() {
        case let s where s.contains("morning"):   return "sunrise.fill"
        case let s where s.contains("afternoon"): return "sun.max.fill"
        case let s where s.contains("evening"):   return "sunset.fill"
        case let s where s.contains("night"):     return "moon.stars.fill"
        default:                                   return "clock.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(sessionDateString(session.date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    // Time-of-day badge with contextual icon + color
                    HStack(spacing: 4) {
                        Image(systemName: timeIcon)
                            .font(.system(size: 9, weight: .bold))
                        Text(session.timeOfDayCategory.label)
                            .font(.caption)
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(timeColor.opacity(0.2))
                    .foregroundColor(timeColor)
                    .clipShape(Capsule())

                    // Best / low badge
                    if let badge = sessionBadge {
                        Text(badge)
                            .font(.system(size: 8, weight: .black))
                            .foregroundColor(badge == "BEST" ? .green : Color(white: 0.55))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(badge == "BEST" ? Color.green.opacity(0.15) : Color.white.opacity(0.07))
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(badge == "BEST" ? Color.green.opacity(0.35) : Color.white.opacity(0.12), lineWidth: 1))
                    }
                }
                HStack(spacing: 12) {
                    Label("\(session.durationSeconds / 60) min", systemImage: "clock")
                    Label("Zen \(session.zenScore)", systemImage: "leaf.fill")
                        .foregroundColor(session.zenScore > 80 ? .green : (session.zenScore > 50 ? .orange : .red))
                    if session.moneySaved > 0 {
                        Label("$\(Int(session.moneySaved))", systemImage: "leaf.circle.fill")
                            .foregroundColor(.green)
                    } else if session.potentialTicketCount > 0 {
                        Label("⚠️ \(session.potentialTicketCount)", systemImage: "")
                            .foregroundColor(.orange)
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.vertical, 8)
    }

    private func sessionDateString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d  h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: date)
    }
}

// MARK: - Session Detail Sheet

struct DriveSessionDetailView: View {
    let session: DriveSession
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        DetailStatBox(title: "Duration", value: "\(session.durationSeconds / 60) min", icon: "clock", color: .cyan)
                        DetailStatBox(title: "Distance", value: String(format: "%.1f mi", session.distanceMiles), icon: "map", color: .blue)
                        DetailStatBox(title: "Avg Speed", value: String(format: "%.0f mph", session.avgSpeedMph), icon: "speedometer", color: .orange)
                        DetailStatBox(title: "Top Speed", value: String(format: "%.0f mph", session.topSpeedMph), icon: "bolt.fill", color: .yellow)
                        DetailStatBox(title: "Zen Score", value: "\(session.zenScore)%", icon: "leaf.fill", color: session.zenScore > 80 ? .green : (session.zenScore > 50 ? .orange : .red))
                        DetailStatBox(title: "Saved", value: "$\(Int(session.moneySaved))", icon: "leaf.circle.fill", color: .green)
                    }
                    .padding(.horizontal)

                    // Speed chart
                    if !session.speedReadings.isEmpty {
                        SpeedChartView(readings: session.speedReadings)
                            .padding(.horizontal)
                    }

                    // Traffic delay
                    if session.trafficDelaySeconds > 60 {
                        HStack {
                            Image(systemName: "car.fill")
                                .foregroundColor(.orange)
                            Text("\(session.trafficDelaySeconds / 60) min slower than expected")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding()
                        .background(Color(white: 0.12))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    // Camera events
                    if !session.cameraZoneEvents.isEmpty {
                        CameraBreakdownCard(events: session.cameraZoneEvents)
                            .padding(.horizontal)
                    }

                    // Mood
                    if let mood = session.mood {
                        HStack {
                            Image(systemName: "face.smiling")
                                .foregroundColor(.cyan)
                            Text("Ride mood: \(mood)")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                            Spacer()
                        }
                        .padding()
                        .background(Color(white: 0.12))
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 40)
                }
                .padding(.top, 20)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(sessionTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
    }

    private var sessionTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mma"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        return formatter.string(from: session.date)
    }
}

private struct DetailStatBox: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.system(size: 24))
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(.white)
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }
}

// MARK: - Simple Speed Sparkline Chart

private struct SpeedChartView: View {
    let readings: [Float]

    var maxSpeed: Float { readings.max() ?? 1 }
    var minSpeed: Float { max(0, (readings.min() ?? 0) - 5) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Speed Profile")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))

            GeometryReader { geo in
                ZStack(alignment: .bottomLeading) {
                    // Background grid lines
                    VStack(spacing: 0) {
                        ForEach(0..<4) { _ in
                            Divider()
                                .background(Color.white.opacity(0.08))
                            Spacer()
                        }
                        Divider()
                            .background(Color.white.opacity(0.08))
                    }

                    // Speed line
                    Path { path in
                        guard readings.count > 1 else { return }
                        let w = geo.size.width
                        let h = geo.size.height
                        let range = maxSpeed - minSpeed
                        let step = w / CGFloat(readings.count - 1)

                        let firstY = h - CGFloat((readings[0] - minSpeed) / range) * h
                        path.move(to: CGPoint(x: 0, y: firstY))

                        for i in 1..<readings.count {
                            let x = CGFloat(i) * step
                            let y = h - CGFloat((readings[i] - minSpeed) / range) * h
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(
                        LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                    )

                    // Fill beneath the line
                    Path { path in
                        guard readings.count > 1 else { return }
                        let w = geo.size.width
                        let h = geo.size.height
                        let range = maxSpeed - minSpeed
                        let step = w / CGFloat(readings.count - 1)

                        let firstY = h - CGFloat((readings[0] - minSpeed) / range) * h
                        path.move(to: CGPoint(x: 0, y: h))
                        path.addLine(to: CGPoint(x: 0, y: firstY))

                        for i in 1..<readings.count {
                            let x = CGFloat(i) * step
                            let y = h - CGFloat((readings[i] - minSpeed) / range) * h
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(
                        colors: [.cyan.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    ))

                    // Peak speed dot + label annotation
                    if readings.count > 1 {
                        let peakIdx = readings.indices.max(by: { readings[$0] < readings[$1] }) ?? 0
                        let step = geo.size.width / CGFloat(readings.count - 1)
                        let range = maxSpeed - minSpeed
                        let px = CGFloat(peakIdx) * step
                        let py = geo.size.height - CGFloat((readings[peakIdx] - minSpeed) / range) * geo.size.height

                        // Outer glow ring
                        Circle()
                            .fill(Color.cyan.opacity(0.18))
                            .frame(width: 18, height: 18)
                            .position(x: px, y: py)

                        // Solid dot
                        Circle()
                            .fill(Color.cyan)
                            .frame(width: 7, height: 7)
                            .shadow(color: .cyan.opacity(0.9), radius: 5)
                            .position(x: px, y: py)

                        // Speed label
                        Text("\(Int(readings[peakIdx]))")
                            .font(.system(size: 9, weight: .black, design: .monospaced))
                            .foregroundColor(.cyan)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(white: 0.14))
                            .clipShape(Capsule())
                            .position(
                                x: min(max(px, 24), geo.size.width - 24),
                                y: max(py - 16, 8)
                            )
                    }
                }
            }
            .frame(height: 80)
            .background(Color(white: 0.08))
            .cornerRadius(10)

            HStack {
                Text("\(Int(minSpeed)) mph")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("Peak \(Int(maxSpeed)) mph")
                    .font(.caption2)
                    .foregroundColor(.cyan.opacity(0.7))
            }
        }
        .padding(14)
        .background(Color(white: 0.12))
        .cornerRadius(14)
    }
}
