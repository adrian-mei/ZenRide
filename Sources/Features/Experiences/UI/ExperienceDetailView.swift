import SwiftUI
import MapKit
import CoreLocation

struct ExperienceDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider

    @StateObject private var customStore = CustomExperienceStore()

    let experience: ExperienceRoute
    var onStart: (() -> Void)?

    @State private var stops: [ExperienceStop]
    @State private var isCustomized: Bool = false

    init(experience: ExperienceRoute, onStart: (() -> Void)? = nil) {
        self.onStart = onStart
        self.experience = experience
        self._stops = State(initialValue: experience.stops.sorted(by: { $0.order < $1.order }))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Map Section
                ZStack(alignment: .bottom) {
                Map {
                    ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                        Annotation(stop.name, coordinate: stop.coordinate) {
                            ZStack {
                                Circle()
                                    .fill(Theme.Colors.acWood)
                                    .frame(width: 30, height: 30)
                                Text("\(index + 1)")
                                    .font(Theme.Typography.button)
                                    .foregroundColor(.white)
                            }
                        }
                    }
                    MapPolyline(coordinates: stops.map { $0.coordinate })
                        .stroke(Theme.Colors.acLeaf, lineWidth: 4)
                }
                .frame(height: 250)

                    // Gradient overlay to blend map into content
                    LinearGradient(
                        gradient: Gradient(colors: [.clear, Theme.Colors.acField.opacity(0.8), Theme.Colors.acField]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 40)
                }

                // Content Section
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(experience.subtitle)
                                .font(Theme.Typography.headline)
                                .foregroundColor(Theme.Colors.acTextDark)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(experience.description)
                                .font(Theme.Typography.body)
                                .foregroundColor(Theme.Colors.acTextMuted)
                                .lineSpacing(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)

                            HStack(spacing: 16) {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock.fill")
                                    Text("\(experience.durationMinutes) min")
                                }
                                HStack(spacing: 4) {
                                    Image(systemName: "map.fill")
                                    Text(experience.city)
                                }
                            }
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.acWood)
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 8)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 16, trailing: 16))
                    }

                    Section {
                        ForEach(Array(stops.enumerated()), id: \.element.id) { index, stop in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack(alignment: .top, spacing: 16) {
                                    // Number Badge
                                    ZStack {
                                        Circle()
                                            .fill(Theme.Colors.acCream)
                                            .frame(width: 32, height: 32)
                                            .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
                                        Text("\(index + 1)")
                                            .font(Theme.Typography.headline)
                                            .foregroundColor(Theme.Colors.acWood)
                                    }
                                    .padding(.top, 2)

                                    // Content
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(stop.name)
                                            .font(Theme.Typography.headline)
                                            .foregroundColor(Theme.Colors.acTextDark)
                                            .fixedSize(horizontal: false, vertical: true)

                                        Text(stop.description)
                                            .font(Theme.Typography.body)
                                            .foregroundColor(Theme.Colors.acTextMuted)
                                            .lineSpacing(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                            .padding(.bottom, 4)

                                        // Start Button
                                        Button {
                                            startExperience(from: index)
                                        } label: {
                                            HStack(spacing: 4) {
                                                Image(systemName: "location.fill")
                                                    .font(Theme.Typography.label)
                                                Text("Start Here")
                                            }
                                            .font(Theme.Typography.label)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Theme.Colors.acWood.opacity(0.1))
                                            .foregroundColor(Theme.Colors.acWood)
                                            .clipShape(Capsule())
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Spacer(minLength: 0)
                                }
                            }
                            .padding(.vertical, 8)
                        }
                        .onMove(perform: moveStops)
                        .listRowBackground(Theme.Colors.acCream)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    } header: {
                        HStack {
                            Text("Destinations")
                                .font(Theme.Typography.title)
                                .foregroundColor(Theme.Colors.acTextDark)
                                .textCase(nil)

                            Spacer()

                            if isCustomized {
                                Button {
                                    withAnimation {
                                        saveCustomOrder()
                                    }
                                } label: {
                                    Text("Save Order")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(ACButtonStyle(variant: .primary))
                            }
                        }
                        .padding(.bottom, 8)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(Theme.Colors.acField)

                // Bottom Button
                VStack {
                    Button {
                        startExperience(from: 0)
                    } label: {
                        HStack {
                            Image(systemName: "map.fill")
                            Text("Start Full Experience")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ACButtonStyle(variant: .largePrimary))
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                .background(Theme.Colors.acField)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: -5)
            }
            .navigationTitle(experience.title)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let saved = customStore.getCustomRoute(for: experience.id) {
                    self.stops = saved.stops
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.acWood.opacity(0.4))
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
        }
    }

    private func moveStops(from source: IndexSet, to destination: Int) {
        stops.move(fromOffsets: source, toOffset: destination)
        isCustomized = true
    }

    private func saveCustomOrder() {
        let custom = CustomExperienceRoute(
            id: UUID().uuidString,
            originalExperienceId: experience.id,
            title: experience.title + " (Custom)",
            stops: stops
        )
        customStore.saveRoute(custom)
        isCustomized = false
    }

    private func startExperience(from startIndex: Int) {
        let remainingStops = Array(stops[startIndex...])
        let waypoints = remainingStops.map { stop in
            QuestWaypoint(
                name: stop.name,
                coordinate: stop.coordinate,
                icon: "star.circle.fill"
            )
        }
        let quest = DailyQuest(title: experience.title, waypoints: waypoints, icon: "star.fill")
                if let (start, end) = routingService.questManager.startQuest(quest, currentLocation: locationProvider.currentLocation?.coordinate) {
            Task {
                if let result = try? await QuestNavigationManager.generateLegRouting(from: start, to: end) {
                    routingService.loadLeg(result: result)
                }
            }
        }
        dismiss()
        onStart?()
    }
}
