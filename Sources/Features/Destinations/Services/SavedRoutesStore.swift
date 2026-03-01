import Foundation
import CoreLocation
import SwiftData

public enum RoutineCategory: String, Codable, CaseIterable {
    case home = "home"
    case work = "work"
    case gym = "gym"
    case partyMember = "party"
    case holySpot = "holy"
    case dayCare = "daycare"
    case school = "school"
    case afterSchool = "afterschool"
    case dateSpot = "datespot"
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .gym: return "dumbbell.fill"
        case .partyMember: return "person.2.fill"
        case .holySpot: return "leaf.fill"
        case .dayCare: return "teddybear.fill"
        case .school: return "figure.and.child.holdinghands"
        case .afterSchool: return "soccerball"
        case .dateSpot: return "heart.fill"
        }
    }
    
    var displayName: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .gym: return "Gym"
        case .partyMember: return "Party Member"
        case .holySpot: return "Holy Spot"
        case .dayCare: return "Day Care"
        case .school: return "School"
        case .afterSchool: return "Afterschool"
        case .dateSpot: return "Date Spot"
        }
    }
}

public struct VisitRecord: Codable {
    public let date: Date
    public let hour: Int
    public let weekday: Int // 1-7
    public let month: Int // 1-12
}

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
    
    // Routine Slotting
    var category: RoutineCategory?
    var slotIndex: Int? // 0, 1, 2
    var contactIdentifier: String? // For party members
    var customIcon: String? // For holy spots
    
    // History for intelligence
    var visitHistory: [VisitRecord] = []
    
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

    init(id: UUID = UUID(), destinationName: String, latitude: Double, longitude: Double, useCount: Int, lastUsedDate: Date, typicalDepartureHours: [Int], averageDurationSeconds: Int, isPinned: Bool = false, offlineRoute: TomTomRoute? = nil, category: RoutineCategory? = nil, slotIndex: Int? = nil, contactIdentifier: String? = nil, customIcon: String? = nil, visitHistory: [VisitRecord] = []) {
        self.id = id
        self.destinationName = destinationName
        self.latitude = latitude
        self.longitude = longitude
        self.useCount = useCount
        self.lastUsedDate = lastUsedDate
        self.typicalDepartureHours = typicalDepartureHours
        self.averageDurationSeconds = averageDurationSeconds
        self.isPinned = isPinned
        self.category = category
        self.slotIndex = slotIndex
        self.contactIdentifier = contactIdentifier
        self.customIcon = customIcon
        self.visitHistory = visitHistory
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
    
    private let key = UserDefaultsKeys.savedRoutes
    private let recentSearchesKey = UserDefaultsKeys.recentSearches
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
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: departureTime)
        let weekday = calendar.component(.weekday, from: departureTime)
        let month = calendar.component(.month, from: departureTime)
        
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
        
        if let idx = routes.firstIndex(where: { $0.id == id }) {
            routes[idx].category = category
            routes[idx].slotIndex = index
            routes[idx].isPinned = true
            routes[idx].contactIdentifier = contactId
            routes[idx].customIcon = customIcon
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
