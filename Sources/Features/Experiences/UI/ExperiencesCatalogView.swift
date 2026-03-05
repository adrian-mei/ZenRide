import SwiftUI

struct ExperiencesCatalogView: View {
    @StateObject private var store = ExperiencesStore()
    @Environment(\.dismiss) private var dismiss
    @State private var selectedExperience: ExperienceRoute?

    // Callbacks to start the trip
    var onSelectExperience: (ExperienceRoute) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.acField.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection

                        if store.experiences.isEmpty {
                            ProgressView()
                                .padding(.top, 100)
                        } else {
                            LazyVStack(spacing: 20) {
                                ForEach(store.experiences) { exp in
                                    ExperienceCard(summary: exp) {
                                        if let route = store.loadExperience(filename: exp.filename) {
                                            selectedExperience = route
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 40)
                }
            }
            .sheet(item: $selectedExperience) { exp in
                ExperienceDetailView(experience: exp, onStart: {
                    onSelectExperience(exp)
                    dismiss()
                })
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Experiences")
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acWood)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(Theme.Typography.title2)
                            .foregroundColor(Theme.Colors.acWood.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Curated Journeys")
                        .font(Theme.Typography.largeTitle)
                        .foregroundColor(Theme.Colors.acWood)

                    Text("Select a journey to start exploring.")
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                }
                Spacer()
                Image(systemName: "tent.fill")
                    .font(Theme.Typography.largeTitle)
                    .foregroundColor(Theme.Colors.acWood.opacity(0.2))
                    .rotationEffect(.degrees(-15))
            }

            HStack(spacing: 8) {
                Label("Verified Spots", systemImage: "checkmark.seal.fill")
                Text("•")
                Label("Scenic Routes", systemImage: "sparkles")
            }
            .font(Theme.Typography.caption)
            .foregroundColor(Theme.Colors.acLeaf)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Theme.Colors.acLeaf.opacity(0.1))
            .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.top, 20)
    }
}

struct ExperienceCard: View {
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
                        .frame(height: 180)
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
                                        .font(Theme.Typography.largeTitle)
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.acWood)
                        .clipShape(Capsule())
                        .padding(12)
                        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(summary.title)
                        .font(Theme.Typography.headline)
                        .foregroundColor(Theme.Colors.acTextDark)

                    Text(summary.subtitle)
                        .font(Theme.Typography.body)
                        .foregroundColor(Theme.Colors.acTextMuted)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .lineSpacing(2)

                    HStack {
                        Spacer()
                        HStack(spacing: 4) {
                            Text("EXPLORE")
                                .font(Theme.Typography.caption)
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        .foregroundColor(Theme.Colors.acLeaf)
                        .padding(.top, 4)
                    }
                }
                .padding(20)
            }
            .background(Theme.Colors.acCream)
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Theme.Colors.acBorder, lineWidth: 2)
            )
            .shadow(color: Theme.Colors.acTextDark.opacity(0.08), radius: 12, x: 0, y: 8)
            .scaleEffect(isPressed ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
        }
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
