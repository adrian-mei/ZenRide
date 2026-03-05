import SwiftUI
import CoreLocation

struct QuestDashboardView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider

    @StateObject private var experiencesStore = ExperiencesStore()

    @State private var selectedExperience: ExperienceRoute?
    @State private var preloadedExperienceWaypoints: [QuestWaypoint] = []
    @State private var preloadedExperienceTitle: String = ""
    @State private var showingBuilder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXPERIENCES")
                        .font(Theme.Typography.button)
                        .foregroundColor(Theme.Colors.acWood)
                        .kerning(1.5)
                    if !experiencesStore.experiences.isEmpty {
                        Text("\(experiencesStore.experiences.count) curated route\(experiencesStore.experiences.count == 1 ? "" : "s")")
                            .font(Theme.Typography.caption)
                            .foregroundColor(Theme.Colors.acTextMuted)
                    }
                }
                Spacer()
            }
            .padding(.horizontal)

            if experiencesStore.experiences.isEmpty {
                ProgressView()
                    .padding()
                    .frame(maxWidth: .infinity)
            } else {
                // Fixed height + scrollClipDisabled so shadows are not clipped at the edge
                // scrollTargetBehavior ensures snappy card-by-card paging
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(experiencesStore.experiences) { exp in
                            ExperienceDashboardCard(summary: exp) {
                                if let route = experiencesStore.loadExperience(filename: exp.filename) {
                                    selectedExperience = route
                                }
                            }
                            .transition(.scale(scale: 0.85).combined(with: .opacity))
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal)
                    .padding(.vertical, 8) // breathing room for shadows
                }
                .frame(height: 240) // slightly taller for the image
                .scrollTargetBehavior(.viewAligned)
                .scrollClipDisabled()
            }
        }

        .sheet(item: $selectedExperience) { experience in
            ExperienceDetailView(experience: experience)
        }
    }

    private func startExperienceImmediately(_ route: ExperienceRoute) {
        let waypoints = route.stops.map { stop in
            QuestWaypoint(
                name: stop.name,
                coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
                icon: "star.circle.fill"
            )
        }
        let quest = DailyQuest(title: route.title, waypoints: waypoints, icon: "star.fill")
                if let (start, end) = routingService.questManager.startQuest(quest, currentLocation: locationProvider.currentLocation?.coordinate) {
            Task {
                do {
                    let result = try await QuestNavigationManager.generateLegRouting(from: start, to: end)
                    routingService.loadLeg(result: result)
                } catch {
                    print("Failed to route")
                }
            }
        }
    }
}

// MARK: - Experience Dashboard Card

struct ExperienceDashboardCard: View {
    let summary: ExperienceSummary
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Hero Image
                ZStack(alignment: .topTrailing) {
                    Rectangle()
                        .fill(Theme.Colors.acSky.opacity(0.15))
                        .frame(height: 120)
                        .overlay(
                            AsyncImage(url: URL(string: summary.thumbnailUrl ?? "")) { phase in
                                switch phase {
                                case .empty:
                                    ZStack {
                                        Theme.Colors.acField
                                        ProgressView().tint(Theme.Colors.acWood)
                                    }
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                case .failure:
                                    Image(systemName: "photo.fill")
                                        .font(.system(size: 30))
                                        .foregroundColor(Theme.Colors.acBorder)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        )
                        .clipped()

                    // Duration Badge
                    Text("\(summary.durationMinutes) min")
                        .font(Theme.Typography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.Colors.acWood)
                        .clipShape(Capsule())
                        .padding(8)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(summary.title)
                        .font(Theme.Typography.body)
                        .bold()
                        .foregroundColor(Theme.Colors.acTextDark)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(summary.subtitle)
                        .font(Theme.Typography.caption)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("EXPLORE")
                                .font(Theme.Typography.label)
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 12))
                        }
                        .foregroundColor(Theme.Colors.acLeaf)
                    }
                }
                .padding(14)
            }
            .frame(width: 252, height: 216)
            .background(Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.Colors.acBorder, lineWidth: 2)
            )
            .shadow(color: Theme.Colors.acTextDark.opacity(0.08), radius: 8, x: 0, y: 4)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
