import Foundation

// MARK: - Vehicle Type

enum VehicleType: String, Codable, CaseIterable {
    // --- Cars ---
    case car
    case sportsCar
    case electricCar
    case suv
    case truck
    // --- Two-wheelers ---
    case motorcycle
    case scooter
    // --- Human-powered ---
    case bicycle
    case mountainBike
    // --- On-foot / micro ---
    case walking
    case running
    case skateboard

    var icon: String {
        switch self {
        case .car:          return "car.fill"
        case .sportsCar:    return "car.rear.fill"
        case .electricCar:  return "bolt.car.fill"
        case .suv:          return "suv.side.fill"
        case .truck:        return "box.truck.fill"
        case .motorcycle:   return "motorcycle"
        case .scooter:      return "scooter"
        case .bicycle:      return "bicycle"
        case .mountainBike: return "figure.outdoor.cycle"
        case .walking:      return "figure.walk"
        case .running:      return "figure.run"
        case .skateboard:   return "skateboard"
        }
    }

    var displayName: String {
        switch self {
        case .car:          return "Car"
        case .sportsCar:    return "Sports"
        case .electricCar:  return "Electric"
        case .suv:          return "SUV"
        case .truck:        return "Truck"
        case .motorcycle:   return "Moto"
        case .scooter:      return "Scooter"
        case .bicycle:      return "Bicycle"
        case .mountainBike: return "MTB"
        case .walking:      return "Walk"
        case .running:      return "Run"
        case .skateboard:   return "Skate"
        }
    }

    var vehicleMode: VehicleMode {
        switch self {
        case .car:          return .car
        case .sportsCar:    return .sportsCar
        case .electricCar:  return .electricCar
        case .suv:          return .suv
        case .truck:        return .truck
        case .motorcycle:   return .motorcycle
        case .scooter:      return .scooter
        case .bicycle:      return .bicycle
        case .mountainBike: return .mountainBike
        case .walking:      return .walking
        case .running:      return .running
        case .skateboard:   return .skateboard
        }
    }

    /// Whether this type represents an on-foot / no-vehicle mode.
    var isOnFoot: Bool {
        switch self {
        case .walking, .running, .skateboard: return true
        default: return false
        }
    }
}

// MARK: - Vehicle Template

struct VehicleTemplate: Identifiable, Equatable {
    let id: String
    let name: String
    let make: String
    let model: String
    let type: VehicleType
    let unlockLevel: Int
    
    // Stats
    let speedStat: Double
    let handlingStat: Double
    let safetyStat: Double
    
    // Default appearance
    let colorHex: String
    
    static let all: [VehicleTemplate] = [
        VehicleTemplate(id: "classic_sedan", name: "Classic Sedan", make: "Standard", model: "Sedan", type: .car, unlockLevel: 1, speedStat: 6.0, handlingStat: 5.0, safetyStat: 9.0, colorHex: "3A86FF"),
        VehicleTemplate(id: "street_bike", name: "Street Bike", make: "Zen", model: "Cruiser", type: .bicycle, unlockLevel: 1, speedStat: 2.0, handlingStat: 10.0, safetyStat: 2.0, colorHex: "FF006E"),
        VehicleTemplate(id: "trail_blazer", name: "Trail Blazer", make: "Zen", model: "MTB", type: .mountainBike, unlockLevel: 3, speedStat: 3.0, handlingStat: 9.0, safetyStat: 4.0, colorHex: "8338EC"),
        VehicleTemplate(id: "eco_glide", name: "Eco Glide", make: "Future", model: "EV", type: .electricCar, unlockLevel: 5, speedStat: 7.0, handlingStat: 8.0, safetyStat: 8.0, colorHex: "38B000"),
        VehicleTemplate(id: "scooter_pro", name: "Scooter Pro", make: "Zen", model: "Kick", type: .scooter, unlockLevel: 8, speedStat: 4.0, handlingStat: 9.0, safetyStat: 3.0, colorHex: "FFBE0B"),
        VehicleTemplate(id: "sport_racer", name: "Sport Racer", make: "Velocity", model: "S1", type: .sportsCar, unlockLevel: 12, speedStat: 10.0, handlingStat: 9.0, safetyStat: 3.0, colorHex: "FF0000"),
        VehicleTemplate(id: "heavy_duty", name: "Heavy Duty", make: "Tough", model: "Truck", type: .truck, unlockLevel: 15, speedStat: 5.0, handlingStat: 3.0, safetyStat: 10.0, colorHex: "5C677D"),
        VehicleTemplate(id: "moto_ninja", name: "Moto Ninja", make: "Speed", model: "Ninja", type: .motorcycle, unlockLevel: 20, speedStat: 9.0, handlingStat: 8.0, safetyStat: 2.0, colorHex: "000000")
    ]
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

    // MARK: - Mario Kart Stats (0.0 to 10.0)
    var speedStat: Double = 5.0
    var handlingStat: Double = 5.0
    var safetyStat: Double = 5.0

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

        if vehicles.isEmpty {
            let defaultBike = Vehicle(
                name: "My Bike",
                make: "Unknown",
                model: "Default",
                year: Calendar.current.component(.year, from: Date()),
                type: .motorcycle,
                colorHex: "00FFFF",
                licensePlate: "",
                odometerMiles: 0
            )
            vehicles.append(defaultBike)
            selectedVehicleId = defaultBike.id
            save()
            Log.info("VehicleStore", "Created default bike")
        } else {
            if let str = UserDefaults.standard.string(forKey: selectedKey),
               let uuid = UUID(uuidString: str),
               vehicles.contains(where: { $0.id == uuid }) {
                selectedVehicleId = uuid
            } else {
                selectedVehicleId = vehicles.first?.id
            }
        }
    }
}
