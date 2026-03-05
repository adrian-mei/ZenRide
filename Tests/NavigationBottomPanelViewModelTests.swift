import Testing
import Foundation
@testable import ZenMap

@MainActor
struct NavigationBottomPanelViewModelTests {

    @Test("Calculates correct route progress")
    func routeProgress() {
        let vm = NavigationBottomPanelViewModel()

        #expect(vm.routeProgress(routeDistanceMeters: 1000, distanceTraveledMeters: 0) == 0.0)
        #expect(vm.routeProgress(routeDistanceMeters: 1000, distanceTraveledMeters: 500) == 0.5)
        #expect(vm.routeProgress(routeDistanceMeters: 1000, distanceTraveledMeters: 1000) == 1.0)
        #expect(vm.routeProgress(routeDistanceMeters: 1000, distanceTraveledMeters: 1500) == 1.0) // clamped
        #expect(vm.routeProgress(routeDistanceMeters: 0, distanceTraveledMeters: 500) == 0.0) // invalid total
    }

    @Test("Calculates correct remaining time")
    func remainingTimeSeconds() {
        let vm = NavigationBottomPanelViewModel()

        #expect(vm.remainingTimeSeconds(routeTimeSeconds: 600, routeDistanceMeters: 1000, distanceTraveledMeters: 0) == 600)
        #expect(vm.remainingTimeSeconds(routeTimeSeconds: 600, routeDistanceMeters: 1000, distanceTraveledMeters: 500) == 300)
        #expect(vm.remainingTimeSeconds(routeTimeSeconds: 600, routeDistanceMeters: 1000, distanceTraveledMeters: 1000) == 0)
    }

    @Test("Calculates remaining distance")
    func remainingDistanceMeters() {
        let vm = NavigationBottomPanelViewModel()

        #expect(vm.remainingDistanceMeters(routeDistanceMeters: 1000, distanceTraveledMeters: 0) == 1000)
        #expect(vm.remainingDistanceMeters(routeDistanceMeters: 1000, distanceTraveledMeters: 500) == 500)
        #expect(vm.remainingDistanceMeters(routeDistanceMeters: 1000, distanceTraveledMeters: 1500) == 0) // clamped
    }

    @Test("Calculates isArriving threshold")
    func isArriving() {
        let vm = NavigationBottomPanelViewModel()

        #expect(vm.isArriving(routeDistanceMeters: 1000, distanceTraveledMeters: 0) == false)
        #expect(vm.isArriving(routeDistanceMeters: 1000, distanceTraveledMeters: 600) == false)
        #expect(vm.isArriving(routeDistanceMeters: 1000, distanceTraveledMeters: 690) == true) // 310m remaining (< 320)
    }

    @Test("Formats distance correctly")
    func distanceFormatting() {
        let vm = NavigationBottomPanelViewModel()

        // Meters if < 1 mile (1609m)
        #expect(vm.distanceValue(routeDistanceMeters: 1000, distanceTraveledMeters: 0) == "1000")
        #expect(vm.distanceUnit(routeDistanceMeters: 1000, distanceTraveledMeters: 0) == "m")

        // Miles if >= 1 mile
        #expect(vm.distanceValue(routeDistanceMeters: 3218, distanceTraveledMeters: 0) == "2.0")
        #expect(vm.distanceUnit(routeDistanceMeters: 3218, distanceTraveledMeters: 0) == "mi")
    }

    @Test("Formats elapsed time correctly")
    func elapsedFormatted() {
        let vm = NavigationBottomPanelViewModel()
        let now = Date()
        vm.now = now

        let startNone: Date? = nil
        #expect(vm.elapsedFormatted(departureTime: startNone) == "0:00")

        let start45SecsAgo = now.addingTimeInterval(-45)
        #expect(vm.elapsedFormatted(departureTime: start45SecsAgo) == "0:45")

        let start5MinsAgo = now.addingTimeInterval(-305) // 5m 5s
        #expect(vm.elapsedFormatted(departureTime: start5MinsAgo) == "5:05")

        let start1HourAgo = now.addingTimeInterval(-3665) // 1h 1m 5s
        #expect(vm.elapsedFormatted(departureTime: start1HourAgo) == "1:01:05")
    }

    @Test("Formats cruise distance correctly")
    func cruiseDistanceFormatted() {
        let vm = NavigationBottomPanelViewModel()

        #expect(vm.cruiseDistanceFormatted(cruiseOdometerMiles: 0.05) == "264 ft")
        #expect(vm.cruiseDistanceUnit(cruiseOdometerMiles: 0.05) == "ft")

        #expect(vm.cruiseDistanceFormatted(cruiseOdometerMiles: 1.5) == "1.5")
        #expect(vm.cruiseDistanceUnit(cruiseOdometerMiles: 1.5) == "mi")
    }

    @Test("Formats current speed correctly")
    func currentSpeedString() {
        let vm = NavigationBottomPanelViewModel()

        #expect(vm.currentSpeedString(currentSpeedMPH: 0) == "0")
        #expect(vm.currentSpeedString(currentSpeedMPH: 25.4) == "25")
        #expect(vm.currentSpeedString(currentSpeedMPH: 65.8) == "66")
        #expect(vm.currentSpeedString(currentSpeedMPH: -10) == "0") // Should clamp
    }
}
