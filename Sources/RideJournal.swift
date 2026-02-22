import Foundation
import SwiftUI
import CoreLocation

struct RideContext {
    let destinationName: String
    let destinationCoordinate: CLLocationCoordinate2D
    let originCoordinate: CLLocationCoordinate2D
    let routeDurationSeconds: Int
    let routeDistanceMeters: Int
    let departureTime: Date
}

struct RideEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let mood: String
    let ticketsAvoided: Int
    // Optional to preserve backward compat with existing UserDefaults data
    var destinationName: String?
    var destinationLatitude: Double?
    var destinationLongitude: Double?
    var originLatitude: Double?
    var originLongitude: Double?
    var routeDurationSeconds: Int?
    var routeDistanceMeters: Int?
    var departureTime: Date?
}

class RideJournal: ObservableObject {
    @Published var entries: [RideEntry] = []

    var totalSaved: Int {
        entries.reduce(0) { $0 + ($1.ticketsAvoided * 100) }
    }

    var totalDistanceMiles: Double {
        let meters = entries.compactMap { $0.routeDistanceMeters }.reduce(0, +)
        return Double(meters) / 1609.34
    }

    init() {
        load()
    }

    func addEntry(mood: String, ticketsAvoided: Int, context: RideContext? = nil) {
        var entry = RideEntry(date: Date(), mood: mood, ticketsAvoided: ticketsAvoided)
        if let ctx = context {
            entry.destinationName = ctx.destinationName
            entry.destinationLatitude = ctx.destinationCoordinate.latitude
            entry.destinationLongitude = ctx.destinationCoordinate.longitude
            entry.originLatitude = ctx.originCoordinate.latitude
            entry.originLongitude = ctx.originCoordinate.longitude
            entry.routeDurationSeconds = ctx.routeDurationSeconds
            entry.routeDistanceMeters = ctx.routeDistanceMeters
            entry.departureTime = ctx.departureTime
        }
        entries.insert(entry, at: 0)
        save()
    }

    private func save() {
        do {
            let data = try JSONEncoder().encode(entries)
            UserDefaults.standard.set(data, forKey: "RideJournalEntries")
        } catch {
            Log.error("RideJournal", "Failed to encode entries: \(error)")
        }
    }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: "RideJournalEntries") else { return }
        do {
            entries = try JSONDecoder().decode([RideEntry].self, from: data)
        } catch {
            Log.error("RideJournal", "Failed to decode entries: \(error)")
        }
    }
}
