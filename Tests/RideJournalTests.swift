import Testing
import Foundation
@testable import ZenMap

// MARK: - Helpers

private func makeJournal() -> RideJournal {
    // Use a unique UserDefaults suite so tests don't share state
    // RideJournal loads from UserDefaults.standard; for isolation we
    // create a fresh instance with no prior data by clearing the key.
    let journal = RideJournal()
    journal.entries = [] // reset any loaded state
    return journal
}

// MARK: - Tests

struct RideJournalTests {

    @Test func freshJournal_totalSavedIsZero() {
        let journal = makeJournal()
        #expect(journal.totalSaved == 0)
    }

    @Test func addEntry_oneTicket_totalSavedIs100() {
        let journal = makeJournal()
        journal.addEntry(mood: "😊", ticketsAvoided: 1)
        #expect(journal.totalSaved == 100)
    }

    @Test func addEntry_nilDistance_doesNotCrash() {
        let journal = makeJournal()
        journal.addEntry(mood: "😊", ticketsAvoided: 0, context: nil)
        #expect(journal.totalDistanceMiles == 0)
    }

    @Test func addEntry_insertsAtFront() {
        let journal = makeJournal()
        journal.addEntry(mood: "first", ticketsAvoided: 0)
        journal.addEntry(mood: "second", ticketsAvoided: 0)
        #expect(journal.entries[0].mood == "second")
    }

    @Test func addEntry_multipleTickets_totalSavedSumsCorrectly() {
        let journal = makeJournal()
        journal.addEntry(mood: "a", ticketsAvoided: 1)
        journal.addEntry(mood: "b", ticketsAvoided: 2)
        journal.addEntry(mood: "c", ticketsAvoided: 3)
        #expect(journal.totalSaved == 600)
    }
}
