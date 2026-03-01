import Foundation
import CoreLocation
import SwiftData

@Model
final class SavedRoute {
    @Attribute(.unique) var id: UUID = UUID()
    var destinationName: String
    var latitude: Double
    var longitude: Double
    var useCount: Int
    var lastUsedDate: Date
    var typicalDepartureHours: [Int]   // capped at 50
    var averageDurationSeconds: Int
    var isPinned: Bool
    
    @Attribute(.externalStorage) var offlineRouteData: Data?

    @Transient var offlineRoute: TomTomRoute? {
        get {
            guard let data = offlineRouteData else { return nil }
            do {
                return try JSONDecoder().decode(TomTomRoute.self, from: data)
            } catch {
                Log.error("SavedRoute", "Failed to decode offline route: \(error)")
                return nil
            }
        }
        set {
            if let value = newValue {
                do {
                    offlineRouteData = try JSONEncoder().encode(value)
                } catch {
                    Log.error("SavedRoute", "Failed to encode offline route: \(error)")
                }
            } else {
                offlineRouteData = nil
            }
        }
    }

    init(id: UUID = UUID(), destinationName: String, latitude: Double, longitude: Double, useCount: Int, lastUsedDate: Date, typicalDepartureHours: [Int], averageDurationSeconds: Int, isPinned: Bool = false, offlineRoute: TomTomRoute? = nil) {
        self.id = id
        self.destinationName = destinationName
        self.latitude = latitude
        self.longitude = longitude
        self.useCount = useCount
        self.lastUsedDate = lastUsedDate
        self.typicalDepartureHours = typicalDepartureHours
        self.averageDurationSeconds = averageDurationSeconds
        self.isPinned = isPinned
        if let offlineRoute = offlineRoute {
            do {
                self.offlineRouteData = try JSONEncoder().encode(offlineRoute)
            } catch {
                Log.error("SavedRoute", "Failed to encode offline route in init: \(error)")
            }
        }
    }
}

struct RecentSearch: Codable, Identifiable {
    var id = UUID()
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date
}

extension Notification.Name {
    static let zenRideNavigateTo = Notification.Name("zenRideNavigateTo")
}

@MainActor
class SavedRoutesStore: ObservableObject {
    @Published var routes: [SavedRoute] = []
    @Published var recentSearches: [RecentSearch] = []
    
    private let key = "SavedRoutes"
    private let recentSearchesKey = "RecentSearches_v1"
    private let defaults: UserDefaults = .standard
    private let context: ModelContext

    init() {
        self.context = SharedModelContainer.shared.mainContext
        migrateIfNecessary()
        load()
        loadRecentSearches()
    }

    // MARK: - Recent Searches
    
    func addRecentSearch(name: String, subtitle: String, coordinate: CLLocationCoordinate2D) {
        let nameTrimmed = name.trimmingCharacters(in: .whitespaces)
        guard !nameTrimmed.isEmpty else { return }
        
        recentSearches.removeAll { $0.name.lowercased() == nameTrimmed.lowercased() }
        let newSearch = RecentSearch(
            name: nameTrimmed,
            subtitle: subtitle,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timestamp: Date()
        )
        recentSearches.insert(newSearch, at: 0)
        
        if recentSearches.count > 10 {
            recentSearches.removeLast()
        }
        saveRecentSearches()
    }

    func deleteRecentSearch(id: UUID) {
        recentSearches.removeAll { $0.id == id }
        saveRecentSearches()
    }

    private func saveRecentSearches() {
        do {
            let data = try JSONEncoder().encode(recentSearches)
            defaults.set(data, forKey: recentSearchesKey)
        } catch {
            Log.error("SavedRoutesStore", "Failed to encode recent searches: \(error)")
        }
    }

    private func loadRecentSearches() {
        guard let data = defaults.data(forKey: recentSearchesKey) else { return }
        do {
            recentSearches = try JSONDecoder().decode([RecentSearch].self, from: data)
        } catch {
            Log.error("SavedRoutesStore", "Failed to decode recent searches: \(error)")
        }
    }

    // MARK: - Pinned / Saved Places

    var pinnedRoutes: [SavedRoute] {
        routes.filter(\.isPinned).sorted { $0.destinationName < $1.destinationName }
    }

    /// Manually save a place the user hasn't visited yet, optionally with an offline route
    func savePlace(name: String, coordinate: CLLocationCoordinate2D, offlineRoute: TomTomRoute? = nil) {
        if let idx = findExistingIndex(near: coordinate, name: name) {
            routes[idx].isPinned = true
            routes[idx].lastUsedDate = Date()
            if let offlineRoute = offlineRoute {
                routes[idx].offlineRoute = offlineRoute
            }
        } else {
            let route = SavedRoute(
                destinationName: name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                useCount: 0,
                lastUsedDate: Date(),
                typicalDepartureHours: [],
                averageDurationSeconds: 0,
                isPinned: true,
                offlineRoute: offlineRoute
            )
            context.insert(route)
            routes.insert(route, at: 0)
        }
        save()
    }

    func togglePin(id: UUID) {
        guard let idx = routes.firstIndex(where: { $0.id == id }) else { return }
        routes[idx].isPinned.toggle()
        save()
        objectWillChange.send()
    }

    func deleteRoute(id: UUID) {
        if let route = routes.first(where: { $0.id == id }) {
            context.delete(route)
        }
        routes.removeAll { $0.id == id }
        save()
    }

    // MARK: - Auto-recorded visit

    func recordVisit(destinationName: String, coordinate: CLLocationCoordinate2D,
                     durationSeconds: Int, departureTime: Date) {
        let hour = Calendar.current.component(.hour, from: departureTime)
        if let idx = findExistingIndex(near: coordinate, name: destinationName) {
            routes[idx].useCount += 1
            routes[idx].lastUsedDate = departureTime
            routes[idx].typicalDepartureHours.append(hour)
            routes[idx].typicalDepartureHours = Array(routes[idx].typicalDepartureHours.suffix(50))
            let prev = routes[idx].averageDurationSeconds
            let count = routes[idx].useCount
            routes[idx].averageDurationSeconds = (prev * (count - 1) + durationSeconds) / count
        } else {
            let route = SavedRoute(
                destinationName: destinationName,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                useCount: 1,
                lastUsedDate: departureTime,
                typicalDepartureHours: [hour],
                averageDurationSeconds: durationSeconds
            )
            context.insert(route)
            routes.insert(route, at: 0)
        }
        save()
    }

    // MARK: - Queries

    func topRecent(limit: Int = 3) -> [SavedRoute] {
        Array(
            routes
                .filter { $0.useCount > 0 }        // only actually visited
                .sorted { $0.lastUsedDate > $1.lastUsedDate }
                .prefix(limit)
        )
    }

    func suggestions(for hour: Int) -> [SavedRoute] {
        guard hour >= 5 && hour <= 23 else { return [] }
        let nearby = hour - 1 ... hour + 1
        return routes
            .filter { route in
                route.useCount >= 2 && route.typicalDepartureHours.contains { nearby.contains($0) }
            }
            .sorted { $0.useCount > $1.useCount }
            .prefix(3)
            .map { $0 }
    }

    // MARK: - Private

    private func findExistingIndex(near coord: CLLocationCoordinate2D, name: String) -> Int? {
        for (i, route) in routes.enumerated() {
            let existingCoord = CLLocationCoordinate2D(latitude: route.latitude, longitude: route.longitude)
            let distance = existingCoord.distance(to: coord)
            let nameMatch = route.destinationName.lowercased() == name.lowercased()
                || route.destinationName.lowercased().hasPrefix(name.lowercased().prefix(5))
            if distance < 150 || (distance < 400 && nameMatch) {
                return i
            }
        }
        return nil
    }

    private func save() {
        do {
            try context.save()
            objectWillChange.send()
        } catch {
            Log.error("SavedRoutesStore", "Failed to save routes: \(error)")
        }
    }

    private func load() {
        do {
            let descriptor = FetchDescriptor<SavedRoute>(sortBy: [SortDescriptor(\.lastUsedDate, order: .reverse)])
            routes = try context.fetch(descriptor)
        } catch {
            Log.error("SavedRoutesStore", "Failed to load routes from SwiftData: \(error)")
        }
    }
    
    // Fallback struct for JSON migration
    struct OldSavedRoute: Codable {
        let destinationName: String
        let latitude: Double
        let longitude: Double
        let useCount: Int
        let lastUsedDate: Date
        let typicalDepartureHours: [Int]
        let averageDurationSeconds: Int
        let isPinned: Bool?
        let offlineRoute: TomTomRoute?
    }

    private func migrateIfNecessary() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        Log.info("SavedRoutesStore", "Migrating old UserDefaults data to SwiftData...")
        do {
            let oldRoutes = try JSONDecoder().decode([OldSavedRoute].self, from: data)
            for old in oldRoutes {
                let newRoute = SavedRoute(
                    destinationName: old.destinationName,
                    latitude: old.latitude,
                    longitude: old.longitude,
                    useCount: old.useCount,
                    lastUsedDate: old.lastUsedDate,
                    typicalDepartureHours: old.typicalDepartureHours,
                    averageDurationSeconds: old.averageDurationSeconds,
                    isPinned: old.isPinned ?? false,
                    offlineRoute: old.offlineRoute
                )
                context.insert(newRoute)
            }
            try context.save()
            UserDefaults.standard.removeObject(forKey: key)
            Log.info("SavedRoutesStore", "Migration complete")
        } catch {
            Log.error("SavedRoutesStore", "Migration failed: \(error)")
        }
    }
}
