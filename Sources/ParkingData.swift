import Foundation

extension Notification.Name {
    static let zenRideParkingRoute = Notification.Name("zenRideParkingRoute")
}

struct ParkingDataFile: Codable {
    let unmetered: [ParkingSpot]
    let metered: [ParkingSpot]
}

struct ParkingSpot: Codable, Identifiable {
    let id: String
    let street: String
    let side: String?
    let spacesCount: Int
    let neighborhood: String?
    let isMetered: Bool
    let latitude: Double
    let longitude: Double
}

class ParkingStore: ObservableObject {
    @Published var spots: [ParkingSpot] = []

    init() {
        loadSpots()
    }

    private func loadSpots() {
        guard let url = Bundle.main.url(forResource: "sf_motorcycle_parking", withExtension: "json") else {
            Log.error("ParkingStore", "sf_motorcycle_parking.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(ParkingDataFile.self, from: data)
            self.spots = file.unmetered + file.metered
            Log.info("ParkingStore", "Loaded \(self.spots.count) parking spots (\(file.unmetered.count) unmetered, \(file.metered.count) metered)")
        } catch {
            Log.error("ParkingStore", "Failed to load parking spots: \(error)")
        }
    }
}
