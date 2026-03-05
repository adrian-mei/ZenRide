import Foundation
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
