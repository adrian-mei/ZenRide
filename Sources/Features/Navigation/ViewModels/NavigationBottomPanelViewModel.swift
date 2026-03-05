import Foundation
import CoreLocation

@MainActor
class NavigationBottomPanelViewModel: ObservableObject {
    @Published var arrivingPulse = false
    @Published var now = Date()

    let arrivalFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm"
        return f
    }()

    func routeProgress(routeDistanceMeters: Int, distanceTraveledMeters: Double) -> Double {
        guard routeDistanceMeters > 0 else { return 0 }
        return min(1, distanceTraveledMeters / Double(routeDistanceMeters))
    }

    func remainingTimeSeconds(routeTimeSeconds: Int, routeDistanceMeters: Int, distanceTraveledMeters: Double) -> Int {
        let progress = routeProgress(routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)
        let remaining = Double(routeTimeSeconds) * (1.0 - progress)
        return max(0, Int(remaining))
    }

    func remainingDistanceMeters(routeDistanceMeters: Int, distanceTraveledMeters: Double) -> Double {
        return max(0, Double(routeDistanceMeters) - distanceTraveledMeters)
    }

    func isArriving(routeDistanceMeters: Int, distanceTraveledMeters: Double) -> Bool {
        remainingDistanceMeters(routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters) < 320
    }

    func arrivalTime(routeTimeSeconds: Int, routeDistanceMeters: Int, distanceTraveledMeters: Double) -> String {
        let remaining = remainingTimeSeconds(routeTimeSeconds: routeTimeSeconds, routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)
        return arrivalFormatter.string(from: now.addingTimeInterval(TimeInterval(remaining)))
    }

    func remainingMinutes(routeTimeSeconds: Int, routeDistanceMeters: Int, distanceTraveledMeters: Double) -> Int {
        let remaining = remainingTimeSeconds(routeTimeSeconds: routeTimeSeconds, routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)
        return max(0, remaining / 60)
    }

    func distanceValue(routeDistanceMeters: Int, distanceTraveledMeters: Double) -> String {
        let remaining = remainingDistanceMeters(routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)
        return remaining < 1609
            ? "\(Int(remaining))"
            : String(format: "%.1f", remaining / Constants.metersPerMile)
    }

    func distanceUnit(routeDistanceMeters: Int, distanceTraveledMeters: Double) -> String {
        let remaining = remainingDistanceMeters(routeDistanceMeters: routeDistanceMeters, distanceTraveledMeters: distanceTraveledMeters)
        return remaining < 1609 ? "m" : "mi"
    }

    // Cruise Mode
    func elapsedFormatted(departureTime: Date?) -> String {
        guard let start = departureTime else { return "0:00" }
        let secs = max(0, Int(now.timeIntervalSince(start)))
        let h = secs / 3600
        let m = (secs % 3600) / 60
        let s = secs % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    func cruiseDistanceFormatted(cruiseOdometerMiles: Double) -> String {
        cruiseOdometerMiles < 0.1
            ? String(format: "%.0f ft", cruiseOdometerMiles * 5280)
            : String(format: "%.1f", cruiseOdometerMiles)
    }

    func cruiseDistanceUnit(cruiseOdometerMiles: Double) -> String {
        cruiseOdometerMiles < 0.1 ? "ft" : "mi"
    }

    func currentSpeedString(currentSpeedMPH: Double) -> String {
        String(format: "%.0f", max(0, currentSpeedMPH))
    }
}
