import Foundation
import CoreLocation

enum RouteMatchResult {
    case onRoute(newIndex: Int)
    case offRoute
}

struct RouteTracker {
    static func match(
        location: CLLocationCoordinate2D,
        activeRoute: [CLLocationCoordinate2D],
        currentIndex: Int,
        offRouteThresholdMeters: Double = 100.0,
        lookAheadSegments: Int = 50
    ) -> RouteMatchResult {
        guard activeRoute.count > 1 else { return .onRoute(newIndex: currentIndex) }

        var minDistance = Double.greatestFiniteMagnitude
        var closestSegmentIndex = currentIndex

        let searchEndIndex = min(currentIndex + lookAheadSegments, activeRoute.count - 1)

        if currentIndex < activeRoute.count - 1 {
            for i in currentIndex..<searchEndIndex {
                let start = activeRoute[i]
                let end = activeRoute[i + 1]
                let distance = location.distanceToSegment(start: start, end: end)
                if distance < minDistance {
                    minDistance = distance
                    closestSegmentIndex = i
                }
            }
        } else {
            guard let lastPoint = activeRoute.last else { return .onRoute(newIndex: currentIndex) }
            minDistance = location.distance(to: lastPoint)
        }

        if minDistance > offRouteThresholdMeters {
            return .offRoute
        }

        let finalIndex = max(currentIndex, min(closestSegmentIndex, activeRoute.count - 1))
        return .onRoute(newIndex: finalIndex)
    }
}
