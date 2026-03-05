import Foundation

struct RecentSearch: Codable, Identifiable {
    var id = UUID()
    var name: String
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var timestamp: Date

    init(id: UUID = UUID(), name: String, subtitle: String, latitude: Double, longitude: Double, timestamp: Date) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.latitude = latitude
        self.longitude = longitude
        self.timestamp = timestamp
    }
}
