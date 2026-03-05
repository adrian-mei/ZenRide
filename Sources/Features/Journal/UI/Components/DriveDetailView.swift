import SwiftUI

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
                                .font(Theme.Typography.largeTitle)
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
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
    }
}
