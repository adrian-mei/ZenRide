import Foundation
import CoreLocation
import SwiftData

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

@Model
final class CameraZoneEvent {
    @Attribute(.unique) var id: UUID = UUID()
    var cameraId: String
    var cameraStreet: String
    var speedLimitMph: Int
    var userSpeedAtZone: Double
    var didSlowDown: Bool
    var outcomeRaw: String

    var outcome: CameraOutcome {
        get { CameraOutcome(rawValue: outcomeRaw) ?? .potentialTicket }
        set { outcomeRaw = newValue.rawValue }
    }

    var moneySaved: Double { outcome == .saved ? 100 : 0 }

    init(id: UUID = UUID(), cameraId: String, cameraStreet: String, speedLimitMph: Int, userSpeedAtZone: Double, didSlowDown: Bool, outcome: CameraOutcome) {
        self.id = id
        self.cameraId = cameraId
        self.cameraStreet = cameraStreet
        self.speedLimitMph = speedLimitMph
        self.userSpeedAtZone = userSpeedAtZone
        self.didSlowDown = didSlowDown
        self.outcomeRaw = outcome.rawValue
    }
}

// MARK: - Drive Session (one actual drive)

@Model
final class DriveSession {
    @Attribute(.unique) var id: UUID = UUID()
    var date: Date
    var departureHour: Int

    var avgSpeedMph: Double
    var topSpeedMph: Double
    var speedReadings: [Float]

    @Relationship(deleteRule: .cascade) var cameraZoneEvents: [CameraZoneEvent]
    var moneySaved: Double

    var trafficDelaySeconds: Int
    var timeOfDayCategoryRaw: String
    var durationSeconds: Int
    var distanceMiles: Double

    var mood: String?
    var zenScore: Int

    var timeOfDayCategory: TimeOfDay {
        get { TimeOfDay(rawValue: timeOfDayCategoryRaw) ?? .midday }
        set { timeOfDayCategoryRaw = newValue.rawValue }
    }

    var savedCameraCount: Int {
        cameraZoneEvents.filter { $0.outcome == .saved }.count
    }
    
    var potentialTicketCount: Int {
        cameraZoneEvents.filter { $0.outcome == .potentialTicket }.count
    }

    init(id: UUID = UUID(), date: Date, departureHour: Int, avgSpeedMph: Double, topSpeedMph: Double, speedReadings: [Float], cameraZoneEvents: [CameraZoneEvent], moneySaved: Double, trafficDelaySeconds: Int, timeOfDayCategory: TimeOfDay, durationSeconds: Int, distanceMiles: Double, mood: String? = nil, zenScore: Int) {
        self.id = id
        self.date = date
        self.departureHour = departureHour
        self.avgSpeedMph = avgSpeedMph
        self.topSpeedMph = topSpeedMph
        self.speedReadings = speedReadings
        self.cameraZoneEvents = cameraZoneEvents
        self.moneySaved = moneySaved
        self.trafficDelaySeconds = trafficDelaySeconds
        self.timeOfDayCategoryRaw = timeOfDayCategory.rawValue
        self.durationSeconds = durationSeconds
        self.distanceMiles = distanceMiles
        self.mood = mood
        self.zenScore = zenScore
    }
}

// MARK: - Drive Record (one route, many sessions)

@Model
final class DriveRecord {
    @Attribute(.unique) var id: UUID = UUID()
    var routeFingerprint: String
    var destinationName: String
    var originLatitude: Double
    var originLongitude: Double
    var destinationLatitude: Double
    var destinationLongitude: Double
    var isBookmarked: Bool
    
    @Relationship(deleteRule: .cascade) var sessions: [DriveSession]

    var sessionCount: Int
    var allTimeAvgSpeedMph: Double
    var allTimeTopSpeedMph: Double
    var allTimeMoneySaved: Double
    var totalDistanceMiles: Double
    var totalTimeDrivenSeconds: Int
    var lastDrivenDate: Date

    var originCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: originLatitude, longitude: originLongitude)
    }

    var destinationCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: destinationLatitude, longitude: destinationLongitude)
    }

    init(id: UUID = UUID(), routeFingerprint: String, destinationName: String, originLatitude: Double, originLongitude: Double, destinationLatitude: Double, destinationLongitude: Double, isBookmarked: Bool = false, sessions: [DriveSession]) {
        self.id = id
        self.routeFingerprint = routeFingerprint
        self.destinationName = destinationName
        self.originLatitude = originLatitude
        self.originLongitude = originLongitude
        self.destinationLatitude = destinationLatitude
        self.destinationLongitude = destinationLongitude
        self.isBookmarked = isBookmarked
        self.sessions = sessions
        self.sessionCount = sessions.count
        self.allTimeAvgSpeedMph = 0
        self.allTimeTopSpeedMph = 0
        self.allTimeMoneySaved = 0
        self.totalDistanceMiles = 0
        self.totalTimeDrivenSeconds = 0
        self.lastDrivenDate = Date()
        updateComputedAggregates()
    }

    func updateComputedAggregates() {
        sessionCount = sessions.count
        lastDrivenDate = sessions.compactMap { $0.date }.max() ?? Date()
        
        var avgSpd: Double = 0
        var topSpd: Double = 0
        var money: Double = 0
        var dist: Double = 0
        var time: Int = 0
        
        for session in sessions {
            avgSpd += session.avgSpeedMph
            if session.topSpeedMph > topSpd { topSpd = session.topSpeedMph }
            money += session.moneySaved
            dist += session.distanceMiles
            time += session.durationSeconds
        }
        
        allTimeAvgSpeedMph = sessions.isEmpty ? 0 : avgSpd / Double(sessions.count)
        allTimeTopSpeedMph = topSpd
        allTimeMoneySaved = money
        totalDistanceMiles = dist
        totalTimeDrivenSeconds = time
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
    let routeDurationSeconds: Int

    func toSession(mood: String? = nil) -> DriveSession {
        let hour = Calendar.current.component(.hour, from: departureTime)
        
        var savedCount = 0
        for event in cameraZoneEvents {
            if event.outcome == .saved { savedCount += 1 }
        }
        let moneySaved = Double(savedCount) * 100
        
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
