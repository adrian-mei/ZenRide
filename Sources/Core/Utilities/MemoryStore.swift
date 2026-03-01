import SwiftUI
import CoreLocation

public struct Memory: Identifiable, Codable {
    public let id: UUID
    public let date: Date
    public let coordinate: CLLocationCoordinate2D
    public let locationName: String
    public let thought: String
    public let mood: String?
    
    public init(id: UUID = UUID(), date: Date = Date(), coordinate: CLLocationCoordinate2D, locationName: String, thought: String, mood: String? = nil) {
        self.id = id
        self.date = date
        self.coordinate = coordinate
        self.locationName = locationName
        self.thought = thought
        self.mood = mood
    }
    
    // Custom Codable for CLLocationCoordinate2D
    enum CodingKeys: String, CodingKey {
        case id, date, latitude, longitude, locationName, thought, mood
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lon)
        locationName = try container.decode(String.self, forKey: .locationName)
        thought = try container.decode(String.self, forKey: .thought)
        mood = try container.decodeIfPresent(String.self, forKey: .mood)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(locationName, forKey: .locationName)
        try container.encode(thought, forKey: .thought)
        try container.encode(mood, forKey: .mood)
    }
}

public class MemoryStore: ObservableObject {
    @Published public var memories: [Memory] = []
    
    private let saveKey = "ZenRide_Memories"
    
    public init() {
        load()
    }
    
    public func capture(at location: CLLocationCoordinate2D, name: String) {
        let thoughts = [
            "The wind feels so refreshing here.",
            "I should bring the whole crew here next time.",
            "This view is etched into my mind forever.",
            "A perfect moment for a road trip story.",
            "I wonder what lies beyond that horizon...",
            "The colors of the sky are just perfect right now.",
            "Just another beautiful day in our journey.",
            "I feel so at peace in this spot."
        ]
        
        let newMemory = Memory(
            coordinate: location,
            locationName: name,
            thought: thoughts.randomElement() ?? "What a beautiful sight!"
        )
        
        withAnimation(.spring()) {
            memories.insert(newMemory, at: 0)
        }
        save()
        
        // Trigger Haptic
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(encoded, forKey: saveKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: saveKey),
           let decoded = try? JSONDecoder().decode([Memory].self, from: data) {
            memories = decoded
        }
    }
}
