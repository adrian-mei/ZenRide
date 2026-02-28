import SwiftUI

struct DriveHistoryView: View {
    @EnvironmentObject var driveStore: DriveStore
    @State private var selectedRecord: DriveRecord? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                
                if driveStore.records.isEmpty {
                    EmptyHistoryView()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            RiderStatsBanner()
                                .padding(.horizontal)
                            
                            // Scrapbook Mementos
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "leaf.fill")
                                        .foregroundColor(Theme.Colors.acLeaf)
                                    Text("Scrapbook Mementos")
                                        .font(Theme.Typography.headline)
                                        .foregroundColor(Theme.Colors.acTextDark)
                                }
                                .padding(.horizontal, 20)
                                .padding(.top, 16)
                                
                                AchievementsShelf()
                                    .padding(.bottom, 16)
                            }
                            .acCardStyle(padding: 0)
                            .padding(.horizontal)
                            
                            // Drive History List
                            VStack(spacing: 16) {
                                ForEach(driveStore.records) { record in
                                    DriveRecordCard(record: record)
                                        .onTapGesture {
                                            selectedRecord = record
                                        }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("Camp Journal")
            .sheet(item: $selectedRecord) { record in
                DriveDetailView(record: record)
            }
        }
    }
}

private struct EmptyHistoryView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.Colors.acWood.opacity(0.5))
            
            Text("Your Journal is empty.")
                .font(Theme.Typography.title)
                .foregroundColor(Theme.Colors.acTextDark)
            
            Text("Take your first road trip to start collecting stamps and memories!")
                .font(Theme.Typography.body)
                .foregroundColor(Theme.Colors.acTextMuted)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

// MARK: - Banner & Components

private struct RiderStatsBanner: View {
    @EnvironmentObject var driveStore: DriveStore
    
    var body: some View {
        HStack(spacing: 12) {
            let streak = driveStore.currentStreak
            StatBox(
                icon: streak > 0 ? "flame.fill" : "flame",
                value: "\(streak)",
                label: "Day Streak",
                color: streak > 0 ? Theme.Colors.acCoral : Theme.Colors.acTextMuted
            )
            
            StatBox(
                icon: "map.fill",
                value: String(format: "%.0f", driveStore.totalDistanceMiles),
                label: "Miles",
                color: Theme.Colors.acSky
            )
            
            StatBox(
                icon: "star.circle.fill",
                value: String(format: "%.0f", driveStore.avgZenScore),
                label: "Avg Score",
                color: Theme.Colors.acGold
            )
        }
    }
}

private struct StatBox: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            Text(value)
                .font(Theme.Typography.headline)
                .foregroundColor(Theme.Colors.acTextDark)
            Text(label)
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundColor(Theme.Colors.acTextMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .acCardStyle(padding: 12)
    }
}

private struct DriveRecordCard: View {
    let record: DriveRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(record.destinationName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(1)
                Spacer()
                if record.isBookmarked {
                    Image(systemName: "bookmark.fill")
                        .foregroundColor(Theme.Colors.acCoral)
                }
            }
            
            HStack {
                Label(shortDate(record.sessions.first?.date ?? Date()), systemImage: "calendar")
                Spacer()
                Label(String(format: "%.1f mi", record.totalDistanceMiles), systemImage: "ruler")
            }
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .foregroundColor(Theme.Colors.acTextMuted)
            
            if record.sessions.count > 1 {
                Text("\(record.sessions.count) stops on this trip")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.Colors.acLeaf)
                    .padding(.top, 4)
            }
        }
        .acCardStyle(interactive: true)
    }
    
    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }
}

// MARK: - Achievements are imported from AchievementSystem.swift

// MARK: - Drive Detail View

struct DriveDetailView: View {
    let record: DriveRecord
    @EnvironmentObject var driveStore: DriveStore
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "map.fill")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.Colors.acLeaf)
                            Text(record.destinationName)
                                .font(Theme.Typography.title)
                                .foregroundColor(Theme.Colors.acTextDark)
                                .multilineTextAlignment(.center)
                            
                            HStack(spacing: 16) {
                                Label(String(format: "%.1f mi", record.totalDistanceMiles), systemImage: "ruler")
                                Label("\(record.sessions.count) stops", systemImage: "car.fill")
                            }
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextMuted)
                        }
                        .padding(.top, 24)
                        
                        // Action buttons
                        HStack(spacing: 16) {
                            Button {
                                driveStore.toggleBookmark(id: record.id)
                            } label: {
                                HStack {
                                    Image(systemName: record.isBookmarked ? "bookmark.fill" : "bookmark")
                                    Text(record.isBookmarked ? "Saved" : "Save Trip")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(ACButtonStyle(variant: record.isBookmarked ? .primary : .secondary))
                            
                            ACDangerButton(title: "Delete", icon: "trash") {
                                driveStore.deleteRecord(id: record.id)
                                dismiss()
                            }
                        }
                        .padding(.horizontal)
                        
                        // Legs / Sessions
                        VStack(alignment: .leading, spacing: 16) {
                            ACSectionHeader(title: "TRIP LEGS", icon: "list.bullet")
                            
                            ForEach(Array(record.sessions.enumerated()), id: \.element.id) { index, session in
                                SessionRow(session: session, index: index + 1)
                            }
                        }
                        .acCardStyle(padding: 20)
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 40)
                }
            }
            .navigationTitle("Trip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
    }
}

private struct SessionRow: View {
    let session: DriveSession
    let index: Int
    
    var body: some View {
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
