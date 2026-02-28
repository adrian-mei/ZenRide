import SwiftUI
import CoreLocation

struct QuestDashboardView: View {
    @EnvironmentObject var questStore: QuestStore
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider

    @State private var showingBuilder = false
    @State private var showingCatalog = false
    @State private var preloadedExperienceWaypoints: [QuestWaypoint] = []
    @State private var preloadedExperienceTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ROUTE BOOK")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Theme.Colors.acWood)
                        .kerning(1.5)
                    if !questStore.quests.isEmpty {
                        Text("\(questStore.quests.count) saved route\(questStore.quests.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)
                    }
                }
                Spacer()
                Button {
                    showingCatalog = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.Colors.acWood)
                        Text("Experiences")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.Colors.acWood)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Theme.Colors.acField)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.Colors.acBorder, lineWidth: 2))
                
                Button {
                    preloadedExperienceTitle = ""
                    preloadedExperienceWaypoints = []
                    showingBuilder = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "plus")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.Colors.acTextDark)
                        Text("New")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(Theme.Colors.acTextDark)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .background(Theme.Colors.acField)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Theme.Colors.acBorder, lineWidth: 2))
            }
            .padding(.horizontal)

            if questStore.quests.isEmpty {
                emptyState
            } else {
                // Fixed height + scrollClipDisabled so shadows are not clipped at the edge
                // scrollTargetBehavior ensures snappy card-by-card paging
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(questStore.quests) { quest in
                            QuestCard(quest: quest,
                                      onStart: {
                                routingService.startQuest(quest,
                                                           currentLocation: locationProvider.currentLocation?.coordinate)
                            },
                                      onDelete: {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    questStore.removeQuest(id: quest.id)
                                }
                            })
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal)
                    .padding(.vertical, 6) // breathing room for shadows
                }
                .frame(height: 216) // explicit height = card 200 + vertical padding 16
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }
        .sheet(isPresented: $showingBuilder) {
            QuestBuilderView(
                preloadedWaypoints: preloadedExperienceWaypoints,
                preloadedTitle: preloadedExperienceTitle
            )
        }
        .sheet(isPresented: $showingCatalog) {
            ExperiencesCatalogView { route in
                preloadedExperienceTitle = route.title
                preloadedExperienceWaypoints = route.stops.map { stop in
                    QuestWaypoint(
                        name: stop.name,
                        coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                        icon: "star.circle.fill"
                    )
                }
                showingBuilder = true
            }
        }
    }

    private var emptyState: some View {
        Button {
            showingBuilder = true
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acLeaf.opacity(0.12))
                        .frame(width: 48, height: 48)
                    Image(systemName: "map.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Theme.Colors.acLeaf)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Build your first route")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)
                    Text("Tap to plan a multi-stop adventure")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(Theme.Colors.acTextMuted)
            }
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Quest Card

struct QuestCard: View {
    let quest: DailyQuest
    let onStart: () -> Void
    let onDelete: () -> Void

    @State private var showDeleteConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Top row: icon + stop count + delete
            HStack(alignment: .top) {
                ZStack {
                    Circle()
                        .fill(Theme.Colors.acLeaf.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: quest.icon)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(Theme.Colors.acLeaf)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 6) {
                    ACBadge(
                        text: "\(quest.waypoints.count) stops",
                        textColor: Theme.Colors.acWood,
                        backgroundColor: Theme.Colors.acWood.opacity(0.12)
                    )

                    Text("+\(quest.waypoints.count * 25) XP")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(Theme.Colors.acLeaf)
                }
            }

            // Title + route summary
            VStack(alignment: .leading, spacing: 4) {
                Text(quest.title)
                    .font(Theme.Typography.title)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if let first = quest.waypoints.first, let last = quest.waypoints.last, first.id != last.id {
                    HStack(spacing: 5) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(Theme.Colors.acTextMuted)
                        Text("\(first.name) → \(last.name)")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            // Action row
            HStack(spacing: 8) {
                Button(action: onStart) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Start")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(ACButtonStyle(variant: .primary))

                Button {
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Theme.Colors.acCoral)
                        .frame(width: 40, height: 40)
                        .background(Theme.Colors.acCoral.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Colors.acCoral.opacity(0.3), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .confirmationDialog("Delete \"\(quest.title)\"?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                    Button("Delete Route", role: .destructive, action: onDelete)
                    Button("Cancel", role: .cancel) {}
                }
            }
        }
        .frame(width: 252, height: 200)
        .acCardStyle(padding: 16, interactive: true)
    }
}
