import Testing
import Foundation
import CoreLocation
@testable import ZenMap

@MainActor
struct VisitHistoryEngineTests {

    @Test("Generates correct visit record")
    func generateRecord() {
        // Create a specific date
        var components = DateComponents()
        components.year = 2024
        components.month = 5
        components.day = 10 // A Friday
        components.hour = 14
        let date = Calendar.current.date(from: components)!

        let record = VisitHistoryEngine.generateRecord(departureTime: date)

        #expect(record.hour == 14)
        #expect(record.month == 5)
        #expect(record.weekday == 6) // Friday is 6 in Calendar.current (Sunday = 1)
        #expect(record.date == date)
    }

    @Test("Updates existing route stats")
    func updateExistingRoute() {
        let route = SavedRoute(
            destinationName: "Office",
            latitude: 10,
            longitude: 10,
            useCount: 1,
            lastUsedDate: Date(),
            typicalDepartureHours: [8],
            averageDurationSeconds: 1200, // 20 mins
            visitHistory: []
        )

        let record = VisitRecord(date: Date(), hour: 9, weekday: 2, month: 1)

        VisitHistoryEngine.updateExistingRoute(route, record: record, durationSeconds: 1800, departureTime: Date())

        #expect(route.useCount == 2)
        #expect(route.typicalDepartureHours == [8, 9])
        #expect(route.visitHistory.count == 1)

        // Average of 1200 and 1800 is 1500
        #expect(route.averageDurationSeconds == 1500)
    }

    @Test("Creates new route correctly")
    func createNewRoute() {
        let date = Date()
        let record = VisitRecord(date: date, hour: 17, weekday: 3, month: 2)

        let coord = CLLocationCoordinate2D(latitude: 37.7, longitude: -122.4)
        let route = VisitHistoryEngine.createNewRoute(
            destinationName: "Gym",
            coordinate: coord,
            record: record,
            durationSeconds: 3600,
            departureTime: date
        )

        #expect(route.destinationName == "Gym")
        #expect(route.latitude == 37.7)
        #expect(route.longitude == -122.4)
        #expect(route.useCount == 1)
        #expect(route.typicalDepartureHours == [17])
        #expect(route.averageDurationSeconds == 3600)
        #expect(route.visitHistory.count == 1)
    }

    @Test("Generates smart suggestions based on time")
    func generateSuggestions() {
        let route1 = SavedRoute(destinationName: "Coffee", latitude: 0, longitude: 0, useCount: 5, lastUsedDate: Date(), typicalDepartureHours: [7, 8, 8], averageDurationSeconds: 600, visitHistory: [])
        let route2 = SavedRoute(destinationName: "Lunch", latitude: 0, longitude: 0, useCount: 3, lastUsedDate: Date(), typicalDepartureHours: [12, 12], averageDurationSeconds: 1200, visitHistory: [])
        let route3 = SavedRoute(destinationName: "Dinner", latitude: 0, longitude: 0, useCount: 4, lastUsedDate: Date(), typicalDepartureHours: [18, 19], averageDurationSeconds: 1800, visitHistory: [])
        let route4 = SavedRoute(destinationName: "Rare", latitude: 0, longitude: 0, useCount: 1, lastUsedDate: Date(), typicalDepartureHours: [8], averageDurationSeconds: 600, visitHistory: [])

        let routes = [route1, route2, route3, route4]

        // 8 AM should suggest Coffee (useCount >= 2, has hour 7, 8, or 9)
        let morning = VisitHistoryEngine.generateSuggestions(routes: routes, for: 8)
        #expect(morning.count == 1)
        #expect(morning.first?.destinationName == "Coffee")

        // 12 PM should suggest Lunch
        let noon = VisitHistoryEngine.generateSuggestions(routes: routes, for: 12)
        #expect(noon.count == 1)
        #expect(noon.first?.destinationName == "Lunch")

        // 'Rare' has 8AM but only 1 use, so it shouldn't be suggested.
        let morning2 = VisitHistoryEngine.generateSuggestions(routes: [route4], for: 8)
        #expect(morning2.isEmpty)
        
        // 3 AM should return nothing (too early)
        let night = VisitHistoryEngine.generateSuggestions(routes: routes, for: 3)
        #expect(night.isEmpty)
    }
}
