import Foundation
import CoreLocation

struct SavedRoute: Codable, Identifiable {
    var id = UUID()
    var destinationName: String
    var latitude: Double
    var longitude: Double
    var useCount: Int
    var lastUsedDate: Date
    var typicalDepartureHours: [Int]   // hours appended per visit, capped at 50
    var averageDurationSeconds: Int
}

extension Notification.Name {
    static let zenRideNavigateTo = Notification.Name("zenRideNavigateTo")
}

class SavedRoutesStore: ObservableObject {
    @Published var routes: [SavedRoute] = []
    private let key = "SavedRoutes"

    init() { load() }

    func recordVisit(destinationName: String, coordinate: CLLocationCoordinate2D,
                     durationSeconds: Int, departureTime: Date) {
        let hour = Calendar.current.component(.hour, from: departureTime)
        if let idx = findExistingIndex(near: coordinate, name: destinationName) {
            routes[idx].useCount += 1
            routes[idx].lastUsedDate = departureTime
            routes[idx].typicalDepartureHours.append(hour)
            routes[idx].typicalDepartureHours = Array(routes[idx].typicalDepartureHours.suffix(50))
            // Rolling average duration
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
            routes.insert(route, at: 0)
        }
        save()
    }

    func topRecent(limit: Int = 3) -> [SavedRoute] {
        Array(routes.sorted { $0.lastUsedDate > $1.lastUsedDate }.prefix(limit))
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

    private func findExistingIndex(near coord: CLLocationCoordinate2D, name: String) -> Int? {
        let target = CLLocation(latitude: coord.latitude, longitude: coord.longitude)
        for (i, route) in routes.enumerated() {
            let existing = CLLocation(latitude: route.latitude, longitude: route.longitude)
            let distance = existing.distance(from: target)
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
            let data = try JSONEncoder().encode(routes)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            Log.error("SavedRoutesStore", "Failed to encode routes: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            routes = try JSONDecoder().decode([SavedRoute].self, from: data)
        } catch {
            Log.error("SavedRoutesStore", "Failed to decode routes: \(error)")
        }
    }
}
