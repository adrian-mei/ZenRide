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
                        ForEach(driveStore.records.sorted(by: { $0.lastDrivenDate > $1.lastDrivenDate })) { record in
                            Button(action: { selectedRecord = record }) {
                                RouteRecordRow(record: record)
                            }
                            .listRowBackground(Color(white: 0.1))
                            .listRowSeparatorTint(Color.white.opacity(0.1))
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
                    ForEach(record.sessions) { session in
                        Button(action: { selectedSession = session }) {
                            SessionRow(session: session)
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

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(sessionDateString(session.date))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    Text(session.timeOfDayCategory.label)
                        .font(.caption)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.blue)
                        .clipShape(Capsule())
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
