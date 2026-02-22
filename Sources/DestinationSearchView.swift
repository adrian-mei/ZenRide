import SwiftUI
import MapKit

class DestinationSearcher: ObservableObject {
    @Published var searchQuery = ""
    @Published var searchResults: [MKMapItem] = []
    
    func search(for query: String, near location: CLLocationCoordinate2D? = nil) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        // Optionally restrict region to user's location or default SF
        let center = location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1))
        request.region = region
        
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            guard let response = response, error == nil else {
                print("Search error: \(error?.localizedDescription ?? "Unknown")")
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
    
    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.body)
                
                TextField("Search Maps", text: $searcher.searchQuery)
                    .focused($isSearchFocused)
                    .onSubmit {
                        searcher.search(for: searcher.searchQuery, near: owlPolice.currentLocation?.coordinate)
                    }
                    .submitLabel(.search)
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
                        CategoryButton(icon: "house.fill", title: "Home", color: .blue)
                        CategoryButton(icon: "briefcase.fill", title: "Work", color: .brown)
                        CategoryButton(icon: "fork.knife", title: "Restaurants", color: .orange)
                        CategoryButton(icon: "fuelpump.fill", title: "Gas Stations", color: .indigo)
                        CategoryButton(icon: "cup.and.saucer.fill", title: "Coffee", color: .orange)
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
                        Divider().padding(.leading, 60)
                        FavoriteRow(icon: "mappin.circle.fill", title: "Golden Gate Park", subtitle: "San Francisco, CA", color: .blue)
                        Divider().padding(.leading, 60)
                        FavoriteRow(icon: "mappin.circle.fill", title: "Alice's Restaurant", subtitle: "Woodside, CA", color: .blue)
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
                    
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Image(systemName: "leaf.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("Saved")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text("$\(owlPolice.camerasPassedThisRide * 100)")
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
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            
            if !searcher.searchResults.isEmpty {
                List(searcher.searchResults, id: \.self) { item in
                    Button(action: {
                        startRouting(to: item)
                    }) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name ?? "Unknown")
                                .font(.headline) // Bolder list item
                                .foregroundColor(.primary)
                            Text(item.placemark.title ?? "")
                                .font(.subheadline) // Larger subtitle
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 8) // Taller tappable area
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
        
        // We need user's current location from OwlPolice
        // If not available, we could use a default SF location
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
    
    var body: some View {
        Button(action: {
            // Placeholder action
            print("Category tapped: \(title)")
        }) {
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
        Button(action: {
            print("Favorite tapped: \(title)")
        }) {
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
