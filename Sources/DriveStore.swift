import Foundation
import CoreLocation

class DriveStore: ObservableObject {
    @Published var records: [DriveRecord] = []
    private let key = "DriveStoreRecords_v1"

    init() { load() }

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
            records.insert(record, at: 0)
            Log.info("DriveStore", "Created new drive record '\(destinationName)' (fingerprint: \(fp))")
        }
        save()
    }

    // MARK: - Aggregate Stats

    var totalSavedAllTime: Double {
        records.reduce(0) { $0 + $1.allTimeMoneySaved }
    }

    var totalRideCount: Int {
        records.reduce(0) { $0 + $1.sessionCount }
    }

    var totalDistanceMiles: Double {
        records.reduce(0) { $0 + $1.totalDistanceMiles }
    }

    var allTimeTopSpeedMph: Double {
        records.map(\.allTimeTopSpeedMph).max() ?? 0
    }

    var mostDrivenRecord: DriveRecord? {
        records.max(by: { $0.sessionCount < $1.sessionCount })
    }

    var avgZenScore: Int {
        let sessions = records.flatMap(\.sessions)
        guard !sessions.isEmpty else { return 0 }
        return sessions.reduce(0) { $0 + $1.zenScore } / sessions.count
    }

    // MARK: - Persistence

    private func save() {
        do {
            let data = try JSONEncoder().encode(records)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            Log.error("DriveStore", "Failed to encode records: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key) else { return }
        do {
            records = try JSONDecoder().decode([DriveRecord].self, from: data)
            Log.info("DriveStore", "Loaded \(records.count) drive records")
        } catch {
            Log.error("DriveStore", "Failed to decode records: \(error)")
        }
    }
}
