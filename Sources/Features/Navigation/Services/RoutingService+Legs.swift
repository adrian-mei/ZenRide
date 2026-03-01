import Foundation
import CoreLocation
import MapKit

/// Extension to handle multi-leg Quests
extension RoutingService {
    
    /// Starts routing a Daily Quest by loading the first leg.
    /// If currentLocation is provided and is not near the first waypoint, it routes to the first waypoint first.
    func startQuest(_ quest: DailyQuest, currentLocation: CLLocationCoordinate2D?) {
        guard !quest.waypoints.isEmpty else { return }
        
        self.activeQuest = quest
        
        if let current = currentLocation {
            let firstWaypoint = quest.waypoints[0].coordinate
            // If we are more than 100 meters from the first stop, route to it first
            if current.distance(to: firstWaypoint) > 100 {
                self.currentLegIndex = -1 // Special index meaning "Heading to Start"
                SpeechService.shared.speak("Starting adventure: \(quest.title). First, let's head to \(quest.waypoints[0].name).")
                self.routeToNextLeg(from: current, to: firstWaypoint)
                return
            }
        }
        
        // Otherwise, start from the first waypoint to the second
        self.currentLegIndex = 0
        guard quest.waypoints.count > 1 else {
            SpeechService.shared.speak("You have arrived at \(quest.waypoints[0].name).")
            return
        }
        
        let startCoord = currentLocation ?? quest.waypoints[0].coordinate
        let destinationCoord = quest.waypoints[1].coordinate
        
        SpeechService.shared.speak("Starting adventure: \(quest.title). Heading to \(quest.waypoints[1].name).")
        self.routeToNextLeg(from: startCoord, to: destinationCoord)
    }
    
    /// Called when the user arrives at an intermediate waypoint
    func advanceToNextLeg(currentLocation: CLLocationCoordinate2D) -> Bool {
        guard let quest = activeQuest else { return false }
        
        // If we were heading to the start (index -1), we just arrived at index 0
        if currentLegIndex == -1 {
            currentLegIndex = 0
        } else {
            currentLegIndex += 1
        }
        
        // Check if we reached the final destination
        if currentLegIndex >= quest.waypoints.count - 1 {
            self.completedQuestWaypointCount = quest.waypoints.count
            self.activeQuest = nil
            SpeechService.shared.speak("You have arrived at your final destination. Adventure complete!")
            return false // Finished entirely
        }
        
        let nextDestination = quest.waypoints[currentLegIndex + 1].coordinate
        SpeechService.shared.speak("Arrived at \(quest.waypoints[currentLegIndex].name). Next stop is \(quest.waypoints[currentLegIndex + 1].name).")
        
        routeToNextLeg(from: currentLocation, to: nextDestination)
        
        return true // Successfully advanced
    }
    
    private func routeToNextLeg(from start: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D) {
        // Fallback to MKDirections for standard iOS routing
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.requestsAlternateRoutes = false // Keep it simple for multi-leg MVP
        
        // Use Automobile for our cozy map style
        request.transportType = .automobile
        
        let directions = MKDirections(request: request)
        directions.calculate { [weak self] response, error in
            guard let self = self, let route = response?.routes.first else {
                Log.error("Routing", "Failed to calculate leg: \(error?.localizedDescription ?? "unknown")")
                return
            }
            
            DispatchQueue.main.async {
                self.activeRoute = route.polyline.coordinates
                self.routeDistanceMeters = Int(route.distance)
                self.routeTimeSeconds = Int(route.expectedTravelTime)
                self.routeProgressIndex = 0
                
                // Parse MKRouteSteps into our custom NavigationInstruction format
                // routeOffsetInMeters is the cumulative distance from route start to each step's
                // starting point, so GuidanceView can correctly compute distance-to-turn.
                var cumulativeMeters = 0
                self.instructions = route.steps.compactMap { step in
                    guard !step.instructions.isEmpty else { return nil }
                    let offset = cumulativeMeters
                    cumulativeMeters += Int(step.distance)
                    return NavigationInstruction(
                        text: step.instructions,
                        distanceInMeters: Int(step.distance),
                        routeOffsetInMeters: offset,
                        pointIndex: 0,
                        turnType: .straight
                    )
                }
                self.currentInstructionIndex = 0
            }
        }
    }
}

// MKPolyline Coordinate Extraction Helper
extension MKPolyline {
    var coordinates: [CLLocationCoordinate2D] {
        var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))
        return coords
    }
}
