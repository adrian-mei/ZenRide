import Testing
import Foundation
@testable import ZenMap

// MARK: - Helpers

private func makeStore() -> VehicleStore {
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.vehicleStoreV1)
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.vehicleStoreSelected)
    UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.vehicleTemplateSelected)
    return VehicleStore()
}

private func makeVehicle(name: String = "Car") -> Vehicle {
    Vehicle(name: name, make: "Test", model: "T1", year: 2024, type: .car,
            colorHex: "FF0000", licensePlate: "", odometerMiles: 0)
}

// MARK: - Tests

struct VehicleStoreTests {

    @Test func removeVehicle_nonSelected_selectionUnchanged() {
        let store = makeStore()
        let bikeA = store.vehicles.first!
        let carB = makeVehicle(name: "CarB")
        store.addVehicle(carB)
        store.removeVehicle(id: carB.id)
        #expect(store.selectedVehicleId == bikeA.id)
    }

    @Test func removeVehicle_selectedVehicle_promotesFirst() {
        let store = makeStore()
        let bikeA = store.vehicles.first!
        let carB = makeVehicle(name: "CarB")
        store.addVehicle(carB)
        store.setDefault(id: carB.id)
        store.removeVehicle(id: carB.id)
        #expect(store.selectedVehicleId == bikeA.id)
    }

    @Test func setDefault_validId_setsSelection() {
        let store = makeStore()
        let carB = makeVehicle(name: "CarB")
        store.addVehicle(carB)
        store.setDefault(id: carB.id)
        #expect(store.selectedVehicleId == carB.id)
    }

    @Test func setDefault_invalidId_doesNotChangeSelection() {
        let store = makeStore()
        let bikeA = store.vehicles.first!
        store.setDefault(id: UUID())
        #expect(store.selectedVehicleId == bikeA.id)
    }
}
