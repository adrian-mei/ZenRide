import SwiftUI
import Charts

struct DriveHistoryView: View {
    @EnvironmentObject var driveStore: DriveStore
    @State private var selectedRecord: DriveRecord?

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

