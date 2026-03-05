import SwiftUI

struct DriveRecordCard: View {
    let record: DriveRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(record.destinationName)
                    .font(Theme.Typography.headline)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
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
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.acTextMuted)

            if record.sessions.count > 1 {
                Text("\(record.sessions.count) stops on this trip")
                    .font(Theme.Typography.caption)
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
