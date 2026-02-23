import Foundation

// MARK: - Vehicle Type

enum VehicleType: String, Codable, CaseIterable {
    case motorcycle
    case car

    var icon: String {
        switch self {
        case .motorcycle: return "figure.motorcycle"
        case .car:        return "car.fill"
        }
    }

    var vehicleMode: VehicleMode {
        switch self {
        case .motorcycle: return .motorcycle
        case .car:        return .car
        }
    }

    var displayName: String {
        switch self {
        case .motorcycle: return "Motorcycle"
        case .car:        return "Car"
        }
    }
}

// MARK: - Vehicle

struct Vehicle: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var make: String
    var model: String
    var year: Int
    var type: VehicleType
    var colorHex: String        // e.g. "00FFFF"
    var licensePlate: String
    var odometerMiles: Double   // manually entered starting odometer
    var photoTimeline: [VehiclePhoto] = []
    var maintenanceLog: [MaintenanceRecord] = []
    var addedDate: Date = Date()
}

// MARK: - Vehicle Photo

struct VehiclePhoto: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var imageData: Data
    var note: String?
}

// MARK: - Maintenance Record

struct MaintenanceRecord: Codable, Identifiable {
    var id: UUID = UUID()
    var date: Date = Date()
    var type: String             // "Oil Change", "Tire", "Chain", "Service", "Other"
    var mileageAtService: Double
    var note: String?
    var cost: Double?
}

// MARK: - VehicleStore

class VehicleStore: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var selectedVehicleId: UUID?

    private let storeKey = "VehicleStore_v1"
    private let selectedKey = "VehicleStore_v1_selected"

    init() { load() }

    // MARK: - Computed

    var selectedVehicle: Vehicle? {
        vehicles.first(where: { $0.id == selectedVehicleId })
    }

    var selectedVehicleMode: VehicleMode {
        selectedVehicle?.type.vehicleMode ?? .motorcycle
    }

    // MARK: - CRUD

    func addVehicle(_ vehicle: Vehicle) {
        vehicles.append(vehicle)
        if selectedVehicleId == nil {
            selectedVehicleId = vehicle.id
        }
        save()
        Log.info("VehicleStore", "Added '\(vehicle.name)' (\(vehicle.type.rawValue))")
    }

    func updateVehicle(_ vehicle: Vehicle) {
        guard let idx = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[idx] = vehicle
        save()
        Log.info("VehicleStore", "Updated '\(vehicle.name)'")
    }

    func removeVehicle(id: UUID) {
        vehicles.removeAll { $0.id == id }
        if selectedVehicleId == id {
            selectedVehicleId = vehicles.first?.id
        }
        save()
        Log.info("VehicleStore", "Removed vehicle \(id)")
    }

    func setDefault(id: UUID) {
        guard vehicles.contains(where: { $0.id == id }) else { return }
        selectedVehicleId = id
        save()
        Log.info("VehicleStore", "Set default vehicle \(id)")
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(vehicles)
            UserDefaults.standard.set(data, forKey: storeKey)
            UserDefaults.standard.set(selectedVehicleId?.uuidString, forKey: selectedKey)
        } catch {
            Log.error("VehicleStore", "Failed to save: \(error)")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: storeKey) {
            do {
                vehicles = try JSONDecoder().decode([Vehicle].self, from: data)
                Log.info("VehicleStore", "Loaded \(vehicles.count) vehicles")
            } catch {
                Log.error("VehicleStore", "Failed to load vehicles: \(error)")
            }
        }

        if let str = UserDefaults.standard.string(forKey: selectedKey),
           let uuid = UUID(uuidString: str),
           vehicles.contains(where: { $0.id == uuid }) {
            selectedVehicleId = uuid
        } else {
            selectedVehicleId = vehicles.first?.id
        }
    }
}
