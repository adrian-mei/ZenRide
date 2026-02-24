import Testing
import Foundation
import CoreLocation
@testable import ZenRide

// MARK: - Helpers

private let coordA = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
private let coordB = CLLocationCoordinate2D(latitude: 37.7750, longitude: -122.4195) // ~15m from A
private let coordC = CLLocationCoordinate2D(latitude: 34.0522, longitude: -118.2437) // far away

private func makeStore() -> SavedRoutesStore {
    let suite = UUID().uuidString
    let defaults = UserDefaults(suiteName: suite)!
    return SavedRoutesStore(defaults: defaults)
}

// MARK: - Tests

struct SavedRoutesStoreTests {

    @Test func savePlaceCreatesNewRoute() {
        let store = makeStore()
        store.savePlace(name: "Park", coordinate: coordA)
        #expect(store.routes.count == 1)
        #expect(store.routes[0].destinationName == "Park")
        #expect(store.routes[0].isPinned == true)
    }

    @Test func savePlaceDeduplicatesWithin150m() {
        let store = makeStore()
        store.savePlace(name: "Park", coordinate: coordA)
        store.savePlace(name: "Park", coordinate: coordB) // ~15m away
        #expect(store.routes.count == 1)
    }

    @Test func savePlaceDeduplicatesWithin400mWithNameMatch() {
        let store = makeStore()
        // Create route at coordA via recordVisit so it already exists
        store.recordVisit(destinationName: "Cafe Nero", coordinate: coordA, durationSeconds: 300, departureTime: Date())
        // Now save with same name, 200m away — should match by name+distance
        let nearA = CLLocationCoordinate2D(latitude: coordA.latitude + 0.001, longitude: coordA.longitude + 0.001) // ~130m
        store.savePlace(name: "Cafe Nero", coordinate: nearA)
        #expect(store.routes.count == 1)
        #expect(store.routes[0].isPinned == true)
    }

    @Test func savePlaceDoesNotDeduplicateFarAway() {
        let store = makeStore()
        store.savePlace(name: "Park", coordinate: coordA)
        store.savePlace(name: "Park", coordinate: coordC) // far away
        #expect(store.routes.count == 2)
    }

    @Test func togglePinFlipsPinnedState() {
        let store = makeStore()
        store.savePlace(name: "Park", coordinate: coordA)
        let id = store.routes[0].id
        store.togglePin(id: id)
        #expect(store.routes[0].isPinned == false)
    }

    @Test func togglePinTwiceRestoresOriginal() {
        let store = makeStore()
        store.savePlace(name: "Park", coordinate: coordA)
        let id = store.routes[0].id
        store.togglePin(id: id)
        store.togglePin(id: id)
        #expect(store.routes[0].isPinned == true)
    }

    @Test func deleteRouteRemovesFromArray() {
        let store = makeStore()
        store.savePlace(name: "Park", coordinate: coordA)
        let id = store.routes[0].id
        store.deleteRoute(id: id)
        #expect(store.routes.isEmpty)
    }

    @Test func recordVisitIncrementsUseCount() {
        let store = makeStore()
        store.recordVisit(destinationName: "Park", coordinate: coordA, durationSeconds: 300, departureTime: Date())
        store.recordVisit(destinationName: "Park", coordinate: coordA, durationSeconds: 400, departureTime: Date())
        #expect(store.routes[0].useCount == 2)
    }

    @Test func recordVisitUpdatesAverageDuration() {
        let store = makeStore()
        store.recordVisit(destinationName: "Park", coordinate: coordA, durationSeconds: 300, departureTime: Date())
        store.recordVisit(destinationName: "Park", coordinate: coordA, durationSeconds: 500, departureTime: Date())
        // avg = (300 + 500) / 2 = 400
        #expect(store.routes[0].averageDurationSeconds == 400)
    }

    @Test func topRecentReturnsOnlyVisited() {
        let store = makeStore()
        store.savePlace(name: "Saved Only", coordinate: coordA)   // useCount = 0
        store.recordVisit(destinationName: "Visited", coordinate: coordC, durationSeconds: 300, departureTime: Date())
        let recent = store.topRecent(limit: 10)
        #expect(recent.count == 1)
        #expect(recent[0].destinationName == "Visited")
    }

    @Test func topRecentSortsByMostRecent() {
        let store = makeStore()
        let calendar = Calendar.current
        let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
        store.recordVisit(destinationName: "Old", coordinate: coordA, durationSeconds: 300, departureTime: yesterday)
        store.recordVisit(destinationName: "New", coordinate: coordC, durationSeconds: 300, departureTime: Date())
        let recent = store.topRecent(limit: 10)
        #expect(recent[0].destinationName == "New")
    }

    @Test func suggestionsMatchesHourRange() {
        let store = makeStore()
        // Record two visits at hour 9
        let nineAM = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        store.recordVisit(destinationName: "Work", coordinate: coordA, durationSeconds: 600, departureTime: nineAM)
        store.recordVisit(destinationName: "Work", coordinate: coordA, durationSeconds: 600, departureTime: nineAM)
        // Suggest for hour 9 — should include
        let suggestions = store.suggestions(for: 9)
        #expect(!suggestions.isEmpty)
        #expect(suggestions[0].destinationName == "Work")
    }

    @Test func suggestionsRequiresMinUseCount() {
        let store = makeStore()
        // Only one visit — useCount < 2
        let nineAM = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        store.recordVisit(destinationName: "Work", coordinate: coordA, durationSeconds: 600, departureTime: nineAM)
        let suggestions = store.suggestions(for: 9)
        #expect(suggestions.isEmpty)
    }

    @Test func suggestionsEmptyOutsideValidHours() {
        let store = makeStore()
        let suggestions = store.suggestions(for: 3) // hour < 5
        #expect(suggestions.isEmpty)
    }

    @Test func pinnedRoutesSortedAlphabetically() {
        let store = makeStore()
        store.savePlace(name: "Zoo", coordinate: coordA)
        store.savePlace(name: "Airport", coordinate: coordC)
        let pinned = store.pinnedRoutes
        #expect(pinned[0].destinationName == "Airport")
        #expect(pinned[1].destinationName == "Zoo")
    }

    @Test func persistenceRoundTrip() {
        let suite = UUID().uuidString
        let defaults = UserDefaults(suiteName: suite)!
        let store1 = SavedRoutesStore(defaults: defaults)
        store1.savePlace(name: "Park", coordinate: coordA)
        store1.recordVisit(destinationName: "Gym", coordinate: coordC, durationSeconds: 300, departureTime: Date())

        let store2 = SavedRoutesStore(defaults: defaults)
        #expect(store2.routes.count == 2)
        let names = store2.routes.map(\.destinationName)
        #expect(names.contains("Park"))
        #expect(names.contains("Gym"))
    }
}
