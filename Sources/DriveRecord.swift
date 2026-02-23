import Foundation
import CoreLocation

// MARK: - Enums

enum CameraOutcome: String, Codable {
    case saved            // slowed to ≤ speed limit inside zone
    case potentialTicket  // remained over limit through zone
}

enum TimeOfDay: String, Codable {
    case morningCommute  // 6-9
    case midday          // 9-16
    case eveningCommute  // 16-19
    case night           // 19-6

    static func from(hour: Int) -> TimeOfDay {
        switch hour {
        case 6..<9:   return .morningCommute
        case 9..<16:  return .midday
        case 16..<19: return .eveningCommute
        default:      return .night
        }
    }

    var label: String {
        switch self {
        case .morningCommute: return "Morning Commute"
        case .midday:         return "Midday"
        case .eveningCommute: return "Evening Commute"
        case .night:          return "Night Ride"
        }
    }
}

// MARK: - Camera Zone Event

struct CameraZoneEvent: Codable, Identifiable {
    var id = UUID()
    var cameraId: String
    var cameraStreet: String
    var speedLimitMph: Int
    var userSpeedAtZone: Double   // speed when entering danger zone
    var didSlowDown: Bool         // speed dropped to ≤ limit before exit
    var outcome: CameraOutcome

    var moneySaved: Double { outcome == .saved ? 100 : 0 }
}

// MARK: - Drive Session (one actual drive)

struct DriveSession: Codable, Identifiable {
    var id = UUID()
    var date: Date
    var departureHour: Int              // 0-23

    // Speed stats
    var avgSpeedMph: Double
    var topSpeedMph: Double
    var speedReadings: [Float]          // sampled every 5s

    // Camera behavior
    var cameraZoneEvents: [CameraZoneEvent]
    var moneySaved: Double              // sum of saved events × $100

    // Conditions
    var trafficDelaySeconds: Int        // actual elapsed vs TomTom ETA
    var timeOfDayCategory: TimeOfDay
    var durationSeconds: Int
    var distanceMiles: Double

    // Outcome
    var mood: String?
    var zenScore: Int

    var savedCameraCount: Int { cameraZoneEvents.filter { $0.outcome == .saved }.count }
    var potentialTicketCount: Int { cameraZoneEvents.filter { $0.outcome == .potentialTicket }.count }
}

// MARK: - Drive Record (one route, many sessions)

struct DriveRecord: Codable, Identifiable {
    var id = UUID()
    var routeFingerprint: String
    var destinationName: String
    var originLatitude: Double
    var originLongitude: Double
    var destinationLatitude: Double
    var destinationLongitude: Double
    var sessions: [DriveSession]        // most recent first

    // Computed aggregates
    var sessionCount: Int { sessions.count }

    var allTimeAvgSpeedMph: Double {
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.avgSpeedMph } / Double(sessions.count)
    }

    var allTimeTopSpeedMph: Double {
        sessions.map(\.topSpeedMph).max() ?? 0
    }

    var allTimeMoneySaved: Double {
        sessions.reduce(0) { $0 + $1.moneySaved }
    }

    var totalDistanceMiles: Double {
        sessions.reduce(0) { $0 + $1.distanceMiles }
    }

    var totalTimeDrivenSeconds: Int {
        sessions.reduce(0) { $0 + $1.durationSeconds }
    }

    var lastDrivenDate: Date {
        sessions.map(\.date).max() ?? Date()
    }

    var originCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude)
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude)
    }
}

// MARK: - Pending Session (built at ride end, mood filled in WindDown)

struct PendingDriveSession {
    let speedReadings: [Float]
    let cameraZoneEvents: [CameraZoneEvent]
    let topSpeedMph: Double
    let avgSpeedMph: Double
    let zenScore: Int
    let departureTime: Date
    let actualDurationSeconds: Int
    let distanceMiles: Double
    let originCoord: CLLocationCoordinate2D
    let destCoord: CLLocationCoordinate2D
    let destinationName: String
    let routeDurationSeconds: Int  // TomTom ETA for delay calculation

    func toSession(mood: String) -> DriveSession {
        let hour = Calendar.current.component(.hour, from: departureTime)
        let moneySaved = Double(cameraZoneEvents.filter { $0.outcome == .saved }.count) * 100
        let trafficDelay = max(0, actualDurationSeconds - routeDurationSeconds)
        return DriveSession(
            date: departureTime,
            departureHour: hour,
            avgSpeedMph: avgSpeedMph,
            topSpeedMph: topSpeedMph,
            speedReadings: speedReadings,
            cameraZoneEvents: cameraZoneEvents,
            moneySaved: moneySaved,
            trafficDelaySeconds: trafficDelay,
            timeOfDayCategory: TimeOfDay.from(hour: hour),
            durationSeconds: actualDurationSeconds,
            distanceMiles: distanceMiles,
            mood: mood,
            zenScore: zenScore
        )
    }
}
