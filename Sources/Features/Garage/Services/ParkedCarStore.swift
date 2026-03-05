import Foundation
import CoreLocation
import SwiftUI

struct ParkedCar: Codable {
    let latitude: Double
    let longitude: Double
    let timestamp: Date
    let streetName: String?
    let notes: String?
    // Optional photo could be saved to disk with a reference ID, for now just text

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

class ParkedCarStore: ObservableObject {
    @Published var parkedCar: ParkedCar?

    private let key = UserDefaultsKeys.parkedCarLocation

    init() {
        load()
    }

    func parkCar(at coordinate: CLLocationCoordinate2D, streetName: String? = nil, notes: String? = nil) {
        let newCar = ParkedCar(
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            timestamp: Date(),
            streetName: streetName,
            notes: notes
        )
        self.parkedCar = newCar
        save()
        Log.info("ParkedCarStore", "Saved parked car at \(coordinate.latitude), \(coordinate.longitude)")
    }

    func unparkCar() {
        self.parkedCar = nil
        UserDefaults.standard.removeObject(forKey: key)
        Log.info("ParkedCarStore", "Removed parked car")
    }

    private func save() {
        guard let car = parkedCar else { return }
        do {
            let data = try JSONEncoder().encode(car)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            Log.error("ParkedCarStore", "Failed to encode parked car: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            self.parkedCar = try JSONDecoder().decode(ParkedCar.self, from: data)
        } catch {
            Log.error("ParkedCarStore", "Failed to decode parked car: \(error)")
        }
    }
}
