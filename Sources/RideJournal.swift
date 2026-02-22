import Foundation
import SwiftUI

struct RideEntry: Codable, Identifiable {
    var id = UUID()
    let date: Date
    let mood: String
    let ticketsAvoided: Int
}

class RideJournal: ObservableObject {
    @Published var entries: [RideEntry] = []
    
    var totalSaved: Int {
        entries.reduce(0) { $0 + ($1.ticketsAvoided * 100) }
    }
    
    init() {
        load()
    }
    
    func addEntry(mood: String, ticketsAvoided: Int) {
        let entry = RideEntry(date: Date(), mood: mood, ticketsAvoided: ticketsAvoided)
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
