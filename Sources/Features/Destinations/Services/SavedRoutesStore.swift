import Foundation
import CoreLocation
import SwiftData





extension Notification.Name {
    static let zenRideNavigateTo = Notification.Name("zenRideNavigateTo")
}

@MainActor
class SavedRoutesStore: ObservableObject {
    @Published var routes: [SavedRoute] = []
    @Published var recentSearches: [RecentSearch] = []

    private let key = UserDefaultsKeys.savedRoutes
    private let recentSearchesKey = UserDefaultsKeys.recentSearches
    private let defaults: UserDefaults
    private let context: ModelContext

    init(context: ModelContext? = nil, defaults: UserDefaults = .standard) {
        self.context = context ?? SharedModelContainer.shared.mainContext
        self.defaults = defaults
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
        defaults.saveJSON(recentSearches, forKey: recentSearchesKey)
    }

    private func loadRecentSearches() {
        recentSearches = defaults.loadJSON([RecentSearch].self, forKey: recentSearchesKey) ?? []
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
        guard routes.update(id: id, { $0.isPinned.toggle() }) else { return }
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
        let hour    = departureTime.hour
        let weekday = departureTime.weekday
        let month   = departureTime.month

        let record = VisitRecord(date: departureTime, hour: hour, weekday: weekday, month: month)

        if let idx = findExistingIndex(near: coordinate, name: destinationName) {
            routes[idx].useCount += 1
            routes[idx].lastUsedDate = departureTime
            routes[idx].typicalDepartureHours.append(hour)
            routes[idx].typicalDepartureHours = Array(routes[idx].typicalDepartureHours.suffix(50))
            routes[idx].visitHistory.append(record)

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
                averageDurationSeconds: durationSeconds,
                visitHistory: [record]
            )
            context.insert(route)
            routes.insert(route, at: 0)
        }
        save()
    }

    func saveAndAssignToRoutine(name: String, coordinate: CLLocationCoordinate2D, category: RoutineCategory, index: Int) {
        // Clear existing slot if any
        for i in 0..<routes.count {
            if routes[i].category == category && routes[i].slotIndex == index {
                routes[i].category = nil
                routes[i].slotIndex = nil
            }
        }

        if let idx = findExistingIndex(near: coordinate, name: name) {
            routes[idx].category = category
            routes[idx].slotIndex = index
            routes[idx].isPinned = true
        } else {
            let route = SavedRoute(
                destinationName: name,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                useCount: 0,
                lastUsedDate: Date(),
                typicalDepartureHours: [],
                averageDurationSeconds: 0,
                visitHistory: []
            )
            route.category = category
            route.slotIndex = index
            route.isPinned = true
            context.insert(route)
            routes.insert(route, at: 0)
        }
        save()
    }

    func assignToRoutine(id: UUID, category: RoutineCategory, index: Int, contactId: String? = nil, customIcon: String? = nil) {
        // Clear existing slot if any
        for i in 0..<routes.count {
            if routes[i].category == category && routes[i].slotIndex == index {
                routes[i].category = nil
                routes[i].slotIndex = nil
            }
        }

        if routes.update(id: id, {
            $0.category = category
            $0.slotIndex = index
            $0.isPinned = true
            $0.contactIdentifier = contactId
            $0.customIcon = customIcon
        }) {
            save()
        }
    }

    func routeForSlot(category: RoutineCategory, index: Int) -> SavedRoute? {
        routes.first { $0.category == category && $0.slotIndex == index }
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

extension SavedRoutesStore {
    func isPlaceSaved(name: String, coordinate: CLLocationCoordinate2D) -> Bool {
        if let idx = findExistingIndex(near: coordinate, name: name) {
            return routes[idx].isPinned
        }
        return false
    }

    func findExistingId(near coord: CLLocationCoordinate2D, name: String) -> UUID? {
        if let idx = findExistingIndex(near: coord, name: name) {
            return routes[idx].id
        }
        return nil
    }
}
