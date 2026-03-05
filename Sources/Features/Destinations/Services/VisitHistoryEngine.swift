import Foundation
import CoreLocation

enum VisitHistoryEngine {
    static func generateRecord(departureTime: Date) -> VisitRecord {
        let hour    = departureTime.hour
        let weekday = departureTime.weekday
        let month   = departureTime.month
        return VisitRecord(date: departureTime, hour: hour, weekday: weekday, month: month)
    }

    static func updateExistingRoute(_ route: SavedRoute, record: VisitRecord, durationSeconds: Int, departureTime: Date) {
        route.useCount += 1
        route.lastUsedDate = departureTime
        route.typicalDepartureHours.append(record.hour)
        route.typicalDepartureHours = Array(route.typicalDepartureHours.suffix(50))
        route.visitHistory.append(record)

        let prev = route.averageDurationSeconds
        let count = route.useCount
        route.averageDurationSeconds = (prev * (count - 1) + durationSeconds) / count
    }

    static func createNewRoute(destinationName: String, coordinate: CLLocationCoordinate2D, record: VisitRecord, durationSeconds: Int, departureTime: Date) -> SavedRoute {
        return SavedRoute(
            destinationName: destinationName,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            useCount: 1,
            lastUsedDate: departureTime,
            typicalDepartureHours: [record.hour],
            averageDurationSeconds: durationSeconds,
            visitHistory: [record]
        )
    }

    static func generateSuggestions(routes: [SavedRoute], for hour: Int) -> [SavedRoute] {
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
}
