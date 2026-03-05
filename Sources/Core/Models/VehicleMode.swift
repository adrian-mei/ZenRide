import Foundation

enum VehicleMode: String, Codable, CaseIterable {
    // Cars
    case car
    case sportsCar
    case electricCar
    case suv
    case truck
    // Two-wheelers
    case motorcycle
    case scooter
    // Human-powered
    case bicycle
    case mountainBike
    // On-foot / micro
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
        case .sportsCar:    return "Sports Car"
        case .electricCar:  return "Electric"
        case .suv:          return "SUV"
        case .truck:        return "Truck"
        case .motorcycle:   return "Motorcycle"
        case .scooter:      return "Scooter"
        case .bicycle:      return "Bicycle"
        case .mountainBike: return "Mountain Bike"
        case .walking:      return "Walking"
        case .running:      return "Running"
        case .skateboard:   return "Skateboard"
        }
    }

    var defaultAvoidCameras: Bool {
        switch self {
        case .motorcycle, .scooter, .sportsCar: return true
        default: return false
        }
    }

    var defaultAvoidHighways: Bool {
        switch self {
        case .bicycle, .mountainBike, .scooter, .walking, .running, .skateboard: return true
        default: return false
        }
    }

    var simulationSpeedMPH: Double {
        switch self {
        case .car, .electricCar, .suv:      return 35
        case .sportsCar:                     return 45
        case .truck:                         return 30
        case .motorcycle, .scooter:         return 35
        case .bicycle, .mountainBike:       return 12
        case .walking:                       return 3
        case .running:                       return 7
        case .skateboard:                    return 8
        }
    }

    var tomTomTravelMode: String {
        switch self {
        case .car, .sportsCar, .electricCar, .suv: return "car"
        case .truck:                                return "truck"
        case .motorcycle, .scooter:                return "motorcycle"
        case .bicycle, .mountainBike:              return "bicycle"
        case .walking, .running, .skateboard:      return "pedestrian"
        }
    }

    var isOnFoot: Bool {
        switch self {
        case .walking, .running, .skateboard: return true
        default: return false
        }
    }
}
