import Foundation
import CoreLocation
import SwiftData

@MainActor
class DriveStore: ObservableObject {
    @Published var records: [DriveRecord] = [] {
        didSet {
            computeStats()
        }
    }
    private let key = "DriveStoreRecords_v1"
    private let context: ModelContext

    init() {
        self.context = SharedModelContainer.shared.mainContext
        migrateIfNecessary()
        load()
    }

    // MARK: - Route Fingerprint

    static func makeFingerprint(origin: CLLocationCoordinate2D, dest: CLLocationCoordinate2D) -> String {
        // Snap to 0.005° grid (~500m resolution) for deduplication
        let oLat = (origin.latitude  / 0.005).rounded() * 0.005
        let oLon = (origin.longitude / 0.005).rounded() * 0.005
        let dLat = (dest.latitude    / 0.005).rounded() * 0.005
        let dLon = (dest.longitude   / 0.005).rounded() * 0.005
        return String(format: "%.4f,%.4f|%.4f,%.4f", oLat, oLon, dLat, dLon)
    }

    // MARK: - Append Session (deduplicates by fingerprint)

    func appendSession(
        originCoord: CLLocationCoordinate2D,
        destCoord: CLLocationCoordinate2D,
        destinationName: String,
        session: DriveSession
    ) {
        let fp = DriveStore.makeFingerprint(origin: originCoord, dest: destCoord)
        if let idx = records.firstIndex(where: { $0.routeFingerprint == fp }) {
            records[idx].sessions.insert(session, at: 0)
            records[idx].updateComputedAggregates()
            Log.info("DriveStore", "Appended session to existing record '\(records[idx].destinationName)' (×\(records[idx].sessionCount))")
        } else {
            let record = DriveRecord(
                routeFingerprint: fp,
                destinationName: destinationName,
                originLatitude: originCoord.latitude,
                originLongitude: originCoord.longitude,
                destinationLatitude: destCoord.latitude,
                destinationLongitude: destCoord.longitude,
                sessions: [session]
            )
            context.insert(record)
            records.insert(record, at: 0)
            Log.info("DriveStore", "Created new drive record '\(destinationName)' (fingerprint: \(fp))")
        }
        save()
    }

    // MARK: - Bookmark

    var bookmarkedRecords: [DriveRecord] {
        records.filter(\.isBookmarked).sorted { $0.lastDrivenDate > $1.lastDrivenDate }
    }

    func toggleBookmark(id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        records[idx].isBookmarked.toggle()
        Log.info("DriveStore", "Bookmark toggled for '\(records[idx].destinationName)'")
        save()
        // Ensure UI updates
        objectWillChange.send()
    }

    func deleteRecord(id: UUID) {
        if let record = records.first(where: { $0.id == id }) {
            context.delete(record)
        }
        records.removeAll { $0.id == id }
        save()
    }

    // MARK: - Aggregate Stats (Cached)
    @Published private(set) var totalSavedAllTime: Double = 0
    @Published private(set) var totalRideCount: Int = 0
    @Published private(set) var totalDistanceMiles: Double = 0
    @Published private(set) var allTimeTopSpeedMph: Double = 0
    @Published private(set) var avgZenScore: Int = 0
    @Published private(set) var currentStreak: Int = 0
    @Published private(set) var todayMiles: Double = 0

    var mostDrivenRecord: DriveRecord? {
        records.max(by: { $0.sessionCount < $1.sessionCount })
    }

    private func computeStats() {
        var saved: Double = 0
        var rides: Int = 0
        var distance: Double = 0
        var topSpeed: Double = 0
        var totalZen: Int = 0
        var sessionCount: Int = 0
        
        for record in records {
            saved += record.allTimeMoneySaved
            rides += record.sessionCount
            distance += record.totalDistanceMiles
            if record.allTimeTopSpeedMph > topSpeed {
                topSpeed = record.allTimeTopSpeedMph
            }
            for session in record.sessions {
                totalZen += session.zenScore
                sessionCount += 1
            }
        }
        
        self.totalSavedAllTime = saved
        self.totalRideCount = rides
        self.totalDistanceMiles = distance
        self.allTimeTopSpeedMph = topSpeed
        self.avgZenScore = sessionCount > 0 ? totalZen / sessionCount : 0
        
        let calendar = Calendar.current
        let allDays = records.flatMap(\.sessions).compactMap { $0.date }.map { calendar.startOfDay(for: $0) }
        let uniqueDays = Array(Set(allDays)).sorted(by: >)

        var streak = 0
        var cursor = calendar.startOfDay(for: Date())

        for day in uniqueDays {
            if calendar.isDate(day, inSameDayAs: cursor) {
                streak += 1
                cursor = calendar.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            } else if day < cursor {
                break
            }
        }
        self.currentStreak = streak
        
        self.todayMiles = records
            .flatMap(\.sessions)
            .filter { calendar.isDateInToday($0.date) }
            .reduce(0) { $0 + $1.distanceMiles }
    }

    // MARK: - Persistence

    private func save() {
        do {
            try context.save()
            computeStats()
        } catch {
            Log.error("DriveStore", "Failed to save to SwiftData: \(error)")
        }
    }

    private func load() {
        do {
            let descriptor = FetchDescriptor<DriveRecord>(sortBy: [SortDescriptor(\.lastDrivenDate, order: .reverse)])
            records = try context.fetch(descriptor)
            Log.info("DriveStore", "Loaded \(records.count) drive records from SwiftData")
        } catch {
            Log.error("DriveStore", "Failed to load records from SwiftData: \(error)")
        }
    }
    
    // Fallback struct for JSON migration
    struct OldDriveRecord: Codable {
        let routeFingerprint: String
        let destinationName: String
        let originLatitude: Double
        let originLongitude: Double
        let destinationLatitude: Double
        let destinationLongitude: Double
        let isBookmarked: Bool?
        let sessions: [OldDriveSession]
    }
    struct OldDriveSession: Codable {
        let date: Date
        let departureHour: Int
        let avgSpeedMph: Double
        let topSpeedMph: Double
        let speedReadings: [Float]
        let cameraZoneEvents: [OldCameraZoneEvent]
        let moneySaved: Double
        let trafficDelaySeconds: Int
        let timeOfDayCategory: TimeOfDay
        let durationSeconds: Int
        let distanceMiles: Double
        let mood: String?
        let zenScore: Int
    }
    struct OldCameraZoneEvent: Codable {
        let cameraId: String
        let cameraStreet: String
        let speedLimitMph: Int
        let userSpeedAtZone: Double
        let didSlowDown: Bool
        let outcome: CameraOutcome
    }
    
    private func migrateIfNecessary() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        Log.info("DriveStore", "Migrating old UserDefaults data to SwiftData...")
        do {
            let oldRecords = try JSONDecoder().decode([OldDriveRecord].self, from: data)
            for old in oldRecords {
                let sessions = old.sessions.map { oldSession in
                    let events = oldSession.cameraZoneEvents.map { oldEvent in
                        CameraZoneEvent(cameraId: oldEvent.cameraId, cameraStreet: oldEvent.cameraStreet, speedLimitMph: oldEvent.speedLimitMph, userSpeedAtZone: oldEvent.userSpeedAtZone, didSlowDown: oldEvent.didSlowDown, outcome: oldEvent.outcome)
                    }
                    return DriveSession(date: oldSession.date, departureHour: oldSession.departureHour, avgSpeedMph: oldSession.avgSpeedMph, topSpeedMph: oldSession.topSpeedMph, speedReadings: oldSession.speedReadings, cameraZoneEvents: events, moneySaved: oldSession.moneySaved, trafficDelaySeconds: oldSession.trafficDelaySeconds, timeOfDayCategory: oldSession.timeOfDayCategory, durationSeconds: oldSession.durationSeconds, distanceMiles: oldSession.distanceMiles, mood: oldSession.mood, zenScore: oldSession.zenScore)
                }
                
                let newRecord = DriveRecord(routeFingerprint: old.routeFingerprint, destinationName: old.destinationName, originLatitude: old.originLatitude, originLongitude: old.originLongitude, destinationLatitude: old.destinationLatitude, destinationLongitude: old.destinationLongitude, isBookmarked: old.isBookmarked ?? false, sessions: sessions)
                context.insert(newRecord)
            }
            try context.save()
            UserDefaults.standard.removeObject(forKey: key)
            Log.info("DriveStore", "Migration complete")
        } catch {
            Log.error("DriveStore", "Migration failed: \(error)")
        }
    }
}
