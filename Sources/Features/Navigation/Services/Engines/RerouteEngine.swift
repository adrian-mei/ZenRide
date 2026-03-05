import Foundation
import CoreLocation

enum RerouteEngine {
    enum RerouteAction {
        case none
        case advanceIndex(Int)
        case promptReroute
    }
    
    static func evaluate(
        currentLocation: CLLocationCoordinate2D,
        activeRoute: [CLLocationCoordinate2D],
        routeProgressIndex: Int,
        isCalculatingRoute: Bool,
        showReroutePrompt: Bool,
        lastRerouteCheckTime: Date?,
        now: Date = Date()
    ) -> (action: RerouteAction, newCheckTime: Date) {
        
        if let last = lastRerouteCheckTime, now.timeIntervalSince(last) < 1.0 {
            return (.none, last)
        }
        
        let matchResult = RouteTracker.match(
            location: currentLocation,
            activeRoute: activeRoute,
            currentIndex: routeProgressIndex
        )

        switch matchResult {
        case .onRoute(let newIndex):
            if newIndex > routeProgressIndex {
                return (.advanceIndex(newIndex), now)
            }
        case .offRoute:
            if !isCalculatingRoute && !showReroutePrompt {
                return (.promptReroute, now)
            }
        }
        
        return (.none, now)
    }
}
