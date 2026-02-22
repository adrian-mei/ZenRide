import SwiftUI
import MapKit

class DestinationSearcher: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [MKMapItem] = []

    private var activeSearch: MKLocalSearch?

    func search(for query: String, near location: CLLocationCoordinate2D? = nil) {
        activeSearch?.cancel()
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let center = location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        request.region = region

        activeSearch = MKLocalSearch(request: request)
        activeSearch?.start { response, error in
            guard let response = response, error == nil else {
                Log.error("Search", "MKLocalSearch failed: \(error?.localizedDescription ?? "unknown")")
                return
            }
            DispatchQueue.main.async {
                self.searchResults = response.mapItems
            }
        }
    }
}

struct DestinationSearchView: View {
    @StateObject private var searcher = DestinationSearcher()
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var cameraStore: CameraStore
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var journal: RideJournal
    
    @Binding var routeState: RouteState
    @Binding var destinationName: String
    @FocusState private var isSearchFocused: Bool

    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    // Mocking an empty favorites list to demonstrate the empty state
    @State private var favorites: [(title: String, subtitle: String)] = []
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)
                
                TextField("Search Maps", text: $searcher.searchQuery)
                    .focused($isSearchFocused)
                    .submitLabel(.search)
                    .onChange(of: searcher.searchQuery) { query in
                        searchTask?.cancel()
                        if query.trimmingCharacters(in: .whitespaces).isEmpty {
                            searcher.searchResults = []
                            isSearching = false
                            return
                        }
                        isSearching = true
                        searchTask = Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            guard !Task.isCancelled else { return }
                            searcher.search(for: query, near: owlPolice.currentLocation?.coordinate)
                            await MainActor.run { isSearching = false }
                        }
                    }
                .font(.body)
                .foregroundColor(.primary)
                
                if !searcher.searchQuery.isEmpty {
                    Button(action: {
                        searcher.searchQuery = ""
                        searcher.searchResults = []
                        isSearchFocused = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                } else {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(.regularMaterial)
            .cornerRadius(10)
            .padding(.horizontal)
            .padding(.top, 16)
            
            if searcher.searchQuery.isEmpty {
                // Quick Categories (Apple Maps Style)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        CategoryButton(icon: "house.fill", title: "Home", color: .blue) {
                            searcher.searchQuery = "Home"
                            searcher.search(for: "home", near: owlPolice.currentLocation?.coordinate)
                        }
                        CategoryButton(icon: "briefcase.fill", title: "Work", color: .brown) {
                            searcher.searchQuery = "Work"
                            searcher.search(for: "work", near: owlPolice.currentLocation?.coordinate)
                        }
                        CategoryButton(icon: "fork.knife", title: "Restaurants", color: .orange) {
                            searcher.searchQuery = "Restaurants"
                            searcher.search(for: "restaurants near me", near: owlPolice.currentLocation?.coordinate)
                        }
                        CategoryButton(icon: "fuelpump.fill", title: "Gas Stations", color: .indigo) {
                            searcher.searchQuery = "Gas Stations"
                            searcher.search(for: "gas station", near: owlPolice.currentLocation?.coordinate)
                        }
                        CategoryButton(icon: "cup.and.saucer.fill", title: "Coffee", color: .orange) {
                            searcher.searchQuery = "Coffee"
                            searcher.search(for: "coffee shop", near: owlPolice.currentLocation?.coordinate)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                
                // Favorites Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Favorites")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 0) {
                        FavoriteRow(icon: "plus", title: "Add", subtitle: "", color: .gray)
                        
                        if favorites.isEmpty {
                            Divider().padding(.leading, 60)
                            HStack {
                                Text("No favorites added yet.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 16)
                        } else {
                            ForEach(favorites, id: \.title) { favorite in
                                Divider().padding(.leading, 60)
                                FavoriteRow(icon: "mappin.circle.fill", title: favorite.title, subtitle: favorite.subtitle, color: .blue)
                            }
                        }
                    }
                    .background(.regularMaterial)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                .padding(.top, 8)
                
                // Ride Archive (ZenRide Custom Integration)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Ride Archive")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.horizontal)
                    
                    if journal.entries.isEmpty && owlPolice.camerasPassedThisRide == 0 {
                        HStack {
                            VStack(alignment: .leading, spacing: 6) {
                                Image(systemName: "car.2.fill")
                                    .font(.title2)
                                    .foregroundColor(.secondary)
                                Text("No rides recorded.")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Complete a trip to see your savings.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(.regularMaterial)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    } else {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "leaf.fill")
                                    .font(.title2)
                                    .foregroundColor(.green)
                                Text("Saved")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("$\((owlPolice.camerasPassedThisRide + journal.totalSaved / 100) * 100)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Image(systemName: "car.fill")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                                Text("Trips")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("\(journal.entries.count)")
                                    .font(.title3)
                                    .fontWeight(.bold)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(.regularMaterial)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            
            if isSearching {
                HStack { Spacer(); ProgressView(); Spacer() }
                    .padding(.vertical, 20)
            } else if !searcher.searchQuery.isEmpty && searcher.searchResults.isEmpty {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    Text("No results for \"\(searcher.searchQuery)\"")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding()
                .background(.regularMaterial)
                .cornerRadius(12)
                .padding(.horizontal)
            } else if !searcher.searchResults.isEmpty {
                List(searcher.searchResults, id: \.self) { item in
                    Button(action: {
                        startRouting(to: item)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "Unknown")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Text(item.placemark.title ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8)
                    }
                    .listRowBackground(Color.clear)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(.regularMaterial)
                .frame(maxHeight: 240)
                .cornerRadius(16)
                .padding(.horizontal)
            }
            
            Spacer()
        }
    }
    
    private func startRouting(to item: MKMapItem) {
        guard let destCoordinate = item.placemark.location?.coordinate else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let origin = owlPolice.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)

        destinationName = item.name ?? "Unknown Destination"

        Task {
            await routingService.calculateSafeRoute(from: origin, to: destCoordinate, avoiding: cameraStore.cameras)
        }

        searcher.searchResults = []
        searcher.searchQuery = ""

        withAnimation {
            routeState = .reviewing
        }
    }
}

struct CategoryButton: View {
    let icon: String
    let title: String
    let color: Color
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color)
                        .frame(width: 56, height: 56)
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
    }
}

struct FavoriteRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        Button(action: {}) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(color)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundColor(color == .gray ? .blue : .primary)
                    if !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
        }
    }
}
