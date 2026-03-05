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
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)

            // Header
            VStack(spacing: 4) {
                Image(systemName: "magnifyingglass.circle.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(Color(hex: "007AFF"))
                Text("Find a Place")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text("Navigate there without ending your drive")
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
            .padding(.bottom, 20)

            // Search bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color.white.opacity(0.5))
                    .font(.system(size: 15, weight: .semibold))

                TextField("Coffee, parking, gas station…", text: $searcher.searchQuery)
                    .focused($focused)
                    .autocorrectionDisabled()
                    .font(.system(size: 16, weight: .medium, design: .default))
                    .foregroundColor(.white)
                    .tint(Color(hex: "007AFF"))
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
                            .foregroundColor(Color.white.opacity(0.5))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1))
            .padding(.horizontal, 16)

            // Results
            ScrollView {
                if searcher.isSearching {
                    VStack(spacing: 8) {
                        ProgressView().tint(.white).padding(.top, 32)
                        Text("Searching nearby…")
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundStyle(Color.white.opacity(0.7))
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
                                            .fill(Color(hex: "007AFF").opacity(0.2))
                                            .frame(width: 40, height: 40)
                                        Image(systemName: "mappin.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(Color(hex: "007AFF"))
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(item.name ?? "Unknown")
                                            .font(.system(size: 16, weight: .bold, design: .default))
                                            .foregroundStyle(.white)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(item.placemark.zenFormattedAddress)
                                            .font(.system(size: 13, weight: .medium, design: .default))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.turn.up.right")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Color(hex: "007AFF"))
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if idx < min(searcher.searchResults.count, 10) - 1 {
                                Divider().background(Color.white.opacity(0.2)).padding(.leading, 68)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                } else if !searcher.searchQuery.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .padding(.top, 32)
                        Text("No results for \"\(searcher.searchQuery)\"")
                            .font(.system(size: 16, weight: .medium, design: .default))
                            .foregroundStyle(Color.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    // Quick category chips
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Quick finds")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                quickChip(icon: "cup.and.saucer.fill", color: Color.orange, label: "Coffee")
                                quickChip(icon: "fuelpump.fill", color: Color.red, label: "Gas")
                                quickChip(icon: "parkingsign.circle.fill", color: Color.blue, label: "Parking")
                                quickChip(icon: "fork.knife", color: Color.green, label: "Food")
                                quickChip(icon: "tree.fill", color: Color.teal, label: "Parks")
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 20)
                }
            }
            .padding(.top, 8)
        }
        .background(Color(hex: "1C1C1E"))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
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
