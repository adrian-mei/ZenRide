import Foundation
import CoreLocation

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

    func spotsNearest(to coordinate: CLLocationCoordinate2D, count: Int = 5) -> [ParkingSpot] {
        let refLat = coordinate.latitude
        let refLng = coordinate.longitude
        let sorted = spots.sorted {
            let d0 = ($0.latitude - refLat) * ($0.latitude - refLat) + ($0.longitude - refLng) * ($0.longitude - refLng)
            let d1 = ($1.latitude - refLat) * ($1.latitude - refLat) + ($1.longitude - refLng) * ($1.longitude - refLng)
            return d0 < d1
        }
        return Array(sorted.prefix(count))
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
