import SwiftUI
import Charts

struct SessionRow: View {
    let session: DriveSession
    let index: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acCream)
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(Theme.Colors.acBorder, lineWidth: 2))
                    Text("\(index)")
                        .font(.system(size: 12, weight: .black, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextDark)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(session.timeOfDayCategory.label)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextDark)

                    HStack(spacing: 12) {
                        Label(String(format: "%.1f mi", session.distanceMiles), systemImage: "ruler")
                        Label(formatDuration(session.durationSeconds), systemImage: "clock")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.acTextMuted)

                    if session.zenScore < 100 {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(Theme.Colors.acCoral)
                            Text("Safety Score: \(session.zenScore)")
                                .foregroundColor(Theme.Colors.acTextDark)
                        }
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .padding(.top, 2)
                    }
                }
                Spacer()
            }

            if !session.speedReadings.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SPEED PROFILE")
                        .font(.system(size: 10, weight: .black, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextMuted)

                    Chart {
                        ForEach(Array(session.speedReadings.enumerated()), id: \.offset) { i, speed in
                            AreaMark(
                                x: .value("Time", i),
                                y: .value("Speed", speed)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Theme.Colors.acSky.opacity(0.5), Theme.Colors.acSky.opacity(0.0)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Time", i),
                                y: .value("Speed", speed)
                            )
                            .foregroundStyle(Theme.Colors.acSky)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                        }
                    }
                    .chartXAxis(.hidden)
                    .chartYAxis {
                        AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                            AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                                .foregroundStyle(Theme.Colors.acBorder)
                            AxisValueLabel()
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(Theme.Colors.acTextMuted)
                        }
                    }
                    .frame(height: 80)
                }
                .padding(.top, 8)
                .padding(.leading, 44) // Align with text
            }
        }
        .padding(.vertical, 8)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        if m < 60 { return "\(m)m" }
        let h = m / 60
        let r = m % 60
        return "\(h)h \(r)m"
    }
}
