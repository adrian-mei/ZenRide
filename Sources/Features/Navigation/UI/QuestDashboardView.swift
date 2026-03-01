import SwiftUI
import CoreLocation

struct QuestDashboardView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var locationProvider: LocationProvider
    
    @StateObject private var experiencesStore = ExperiencesStore()

    @State private var selectedExperience: ExperienceRoute?
    @State private var showingExperienceAction = false
    @State private var preloadedExperienceWaypoints: [QuestWaypoint] = []
    @State private var preloadedExperienceTitle: String = ""
    @State private var showingBuilder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("EXPERIENCES")
                        .font(.system(size: 14, weight: .black, design: .rounded))
                        .foregroundColor(Theme.Colors.acWood)
                        .kerning(1.5)
                    if !experiencesStore.experiences.isEmpty {
                        Text("\(experiencesStore.experiences.count) curated route\(experiencesStore.experiences.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
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
                                    showingExperienceAction = true
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
        .confirmationDialog(
            selectedExperience?.title ?? "Experience",
            isPresented: $showingExperienceAction,
            titleVisibility: .visible
        ) {
            Button("Start Adventure Now") {
                if let route = selectedExperience {
                    startExperienceImmediately(route)
                }
            }
            Button("Customize Route") {
                if let route = selectedExperience {
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
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(selectedExperience?.subtitle ?? "")
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
        routingService.startQuest(quest, currentLocation: locationProvider.currentLocation?.coordinate)
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
                        .font(.system(size: 11, weight: .black, design: .rounded))
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
                        .font(.system(size: 16, weight: .black, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextDark)
                        .lineLimit(1)
                    
                    Text(summary.subtitle)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .lineSpacing(2)
                    
                    Spacer(minLength: 0)
                    
                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("EXPLORE")
                                .font(.system(size: 11, weight: .black, design: .rounded))
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
