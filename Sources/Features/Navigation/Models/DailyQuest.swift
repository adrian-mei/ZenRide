import Foundation
import CoreLocation
import MapKit

/// Represents a specific stop/waypoint in a user's Daily Quest
struct QuestWaypoint: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var coordinate: CLLocationCoordinate2D
    var icon: String // e.g. "house.fill", "cup.and.saucer.fill", "building.2.fill"
    
    // Codable support for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, name, latitude, longitude, icon
    }
    
    init(id: UUID = UUID(), name: String, coordinate: CLLocationCoordinate2D, icon: String = "mappin.circle.fill") {
        self.id = id
        self.name = name
        self.coordinate = coordinate
        self.icon = icon
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        icon = try container.decode(String.self, forKey: .icon)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lng = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(icon, forKey: .icon)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
    }
}

/// A "Daily Quest" is a saved, multi-leg routine (e.g. Morning Commute: Home -> Coffee -> School -> Work)
struct DailyQuest: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var waypoints: [QuestWaypoint]
    var creationDate: Date = Date()
    var icon: String = "map.fill"
}

/// Store to persist user's custom daily quests
class QuestStore: ObservableObject {
    @Published var quests: [DailyQuest] = []
    
    private let storageKey = "FashodaMap_Quests_v1"
    
    init() { load() }
    
    func addQuest(_ quest: DailyQuest) {
        quests.append(quest)
        save()
    }
    
    func removeQuest(at offsets: IndexSet) {
        quests.remove(atOffsets: offsets)
        save()
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(quests) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([DailyQuest].self, from: data) {
            self.quests = decoded
        } else {
            // Seed a default quest for the MVP
            let sfHome = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
            let sfCoffee = CLLocationCoordinate2D(latitude: 37.7800, longitude: -122.4200)
            let sfWork = CLLocationCoordinate2D(latitude: 37.7850, longitude: -122.4000)
            
            let defaultQuest = DailyQuest(
                title: "Morning Routine",
                waypoints: [
                    QuestWaypoint(name: "Home", coordinate: sfHome, icon: "house.fill"),
                    QuestWaypoint(name: "Coffee Shop", coordinate: sfCoffee, icon: "cup.and.saucer.fill"),
                    QuestWaypoint(name: "Office", coordinate: sfWork, icon: "briefcase.fill")
                ],
                icon: "sun.max.fill"
            )
            self.quests = [defaultQuest]
            save()
        }
    }
}
