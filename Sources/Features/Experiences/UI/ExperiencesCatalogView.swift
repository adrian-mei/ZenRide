import SwiftUI

struct ExperiencesCatalogView: View {
    @StateObject private var store = ExperiencesStore()
    @Environment(\.dismiss) private var dismiss
    
    // Callbacks to start the trip
    var onSelectExperience: (ExperienceRoute) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        Text("Curated Journeys")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.acWood)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.top, 10)
                        
                        Text("Explore hand-picked routes to see the best of the city.")
                            .font(Theme.Typography.body)
                            .foregroundColor(Theme.Colors.acTextMuted)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                            .padding(.bottom, 10)
                        
                        if store.experiences.isEmpty {
                            ProgressView()
                                .padding(.top, 50)
                        } else {
                            ForEach(store.experiences) { exp in
                                ExperienceCard(summary: exp) {
                                    if let route = store.loadExperience(filename: exp.filename) {
                                        onSelectExperience(route)
                                        dismiss()
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("Experiences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundColor(Theme.Colors.acWood)
                }
            }
        }
    }
}

struct ExperienceCard: View {
    let summary: ExperienceSummary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {
                // Placeholder for an image if needed
                Rectangle()
                    .fill(Theme.Colors.acSky.opacity(0.3))
                    .frame(height: 140)
                    .overlay(
                        AsyncImage(url: URL(string: summary.thumbnailUrl ?? "")) { phase in
                            switch phase {
                            case .empty:
                                ProgressView()
                            case .success(let image):
                                image.resizable().aspectRatio(contentMode: .fill)
                            case .failure:
                                Image(systemName: "photo.fill").foregroundColor(.white)
                            @unknown default:
                                EmptyView()
                            }
                        }
                    )
                    .clipped()
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(summary.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.acTextDark)
                        Spacer()
                        Text("\(summary.durationMinutes) min")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Theme.Colors.acWood)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Theme.Colors.acWood.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    
                    Text(summary.subtitle)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }
                .padding(16)
            }
            .background(Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 1))
            .shadow(color: Theme.Colors.acTextDark.opacity(0.05), radius: 6, x: 0, y: 3)
            .padding(.horizontal)
        }
        .buttonStyle(.plain)
    }
}
