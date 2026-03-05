import SwiftUI
import MapKit
import UIKit

/// Lightweight mid-cruise destination search sheet.
/// Lets the user pick a place to navigate to without ending the drive.
struct CruiseSearchSheet: View {
    var onDestinationSelected: (String, CLLocationCoordinate2D) -> Void

    @EnvironmentObject var locationProvider: LocationProvider

    @EnvironmentObject var savedRoutes: SavedRoutesStore
    @StateObject private var searcher = DestinationSearcher()
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Handle
            Capsule()
                .fill(Theme.Colors.acBorder.opacity(0.5))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            VStack(spacing: 4) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(Theme.Typography.largeTitle)
                    .foregroundStyle(Theme.Colors.acAction)
                Text("Find a Place")
                    .font(Theme.Typography.title2)
                    .foregroundStyle(Theme.Colors.acTextDark)
                Text("Navigate there without ending your drive")
                    .font(Theme.Typography.body)
                    .foregroundStyle(Theme.Colors.acTextMuted)
            }
            .padding(.bottom, 20)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.Colors.acTextMuted)
                    .font(Theme.Typography.button)

                TextField("Coffee, parking, gas station…", text: $searcher.searchQuery)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .font(Theme.Typography.body)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .tint(Theme.Colors.acAction)
                    .submitLabel(.search)
                    .onChange(of: searcher.searchQuery) { _, query in
                        searcher.scheduleSearch(for: query, near: locationProvider.currentLocation?.coordinate, recentSearches: savedRoutes.recentSearches)
                    }
                    .onSubmit {
                        let q = searcher.searchQuery.trimmingCharacters(in: .whitespaces)
                        guard !q.isEmpty else { return }
                        searcher.search(for: q, near: locationProvider.currentLocation?.coordinate, recentSearches: savedRoutes.recentSearches)
                    }

                if !searcher.searchQuery.isEmpty {
                    Button {
                        searcher.searchQuery = ""
                        searcher.searchResults = []
                        focused = true
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.Colors.acTextMuted)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Theme.Colors.acField)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 1))
            .padding(.horizontal, 16)

            // Results
            ScrollView {
                if searcher.isSearching {
                    VStack(spacing: 8) {
                        ProgressView().tint(Theme.Colors.acAction).padding(.top, 32)
                        Text("Searching nearby…")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.acTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                } else if !searcher.searchResults.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(searcher.searchResults.prefix(10).enumerated()), id: \.offset) { idx, item in
                            Button {
                                guard let coord = item.placemark.location?.coordinate else { return }
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onDestinationSelected(item.name ?? "Destination", coord)
                            } label: {
                                HStack(spacing: 12) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .fill(Theme.Colors.acAction.opacity(0.1))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "mappin.circle.fill")
                                            .font(Theme.Typography.headline)
                                            .foregroundStyle(Theme.Colors.acAction)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name ?? "Unknown")
                                            .font(Theme.Typography.body)
                                            .bold()
                                            .foregroundStyle(Theme.Colors.acTextDark)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(item.placemark.zenFormattedAddress)
                                            .font(Theme.Typography.caption)
                                            .foregroundStyle(Theme.Colors.acTextMuted)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.turn.up.right")
                                        .font(Theme.Typography.button)
                                        .foregroundStyle(Theme.Colors.acAction)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if idx < min(searcher.searchResults.count, 10) - 1 {
                                Divider().background(Theme.Colors.acBorder.opacity(0.5)).padding(.leading, 68)
                            }
                        }
                    }
                    .background(Theme.Colors.acCream)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.Colors.acBorder, lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                } else if !searcher.searchQuery.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(Theme.Typography.title)
                            .foregroundStyle(Theme.Colors.acTextMuted)
                            .padding(.top, 32)
                        Text("No results for \"\(searcher.searchQuery)\"")
                            .font(Theme.Typography.body)
                            .foregroundStyle(Theme.Colors.acTextMuted)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Quick category chips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick finds")
                            .font(Theme.Typography.button)
                            .foregroundStyle(Theme.Colors.acWood)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                quickChip(icon: "cup.and.saucer.fill", color: Theme.Colors.acWood, label: "Coffee")
                                quickChip(icon: "fuelpump.fill", color: Theme.Colors.acCoral, label: "Gas")
                                quickChip(icon: "parkingsign.circle.fill", color: Theme.Colors.acSky, label: "Parking")
                                quickChip(icon: "fork.knife", color: Theme.Colors.acLeaf, label: "Food")
                                quickChip(icon: "tree.fill", color: Theme.Colors.acGrass, label: "Parks")
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.top, 8)
        }
        .background(Theme.Colors.acCream)
        .onAppear { focused = true }
    }

    @ViewBuilder
    private func quickChip(icon: String, color: Color, label: String) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            searcher.searchQuery = label
            searcher.search(for: label, near: locationProvider.currentLocation?.coordinate, recentSearches: savedRoutes.recentSearches)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(Theme.Typography.caption)
                    .foregroundStyle(color)
                Text(label)
                    .font(Theme.Typography.button)
                    .foregroundStyle(Theme.Colors.acTextDark)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(color.opacity(0.2))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(color.opacity(0.4), lineWidth: 1.5))
        }
        .buttonStyle(.plain)
    }
}
