import Foundation
import CoreLocation
import MapKit

/// Extension to handle multi-leg Quests
extension RoutingService {
    
    /// Starts routing a Daily Quest by loading the first leg
    func startQuest(_ quest: DailyQuest, currentLocation: CLLocationCoordinate2D?) {
        guard quest.waypoints.count > 1 else { return }
        
        // We will store the full quest state in a new property (which we'll add to the main class)
        self.activeQuest = quest
        self.currentLegIndex = 0
        
        let startCoord = currentLocation ?? quest.waypoints[0].coordinate
        let destinationCoord = quest.waypoints[1].coordinate
        
        self.routeToNextLeg(from: startCoord, to: destinationCoord)
    }
    
    /// Called when the user arrives at an intermediate waypoint
    func advanceToNextLeg(currentLocation: CLLocationCoordinate2D) -> Bool {
        guard let quest = activeQuest else { return false }
        
        currentLegIndex += 1
        
        // Check if we reached the final destination
        if currentLegIndex >= quest.waypoints.count - 1 {
            self.activeQuest = nil
            SpeechService.shared.speak("You have arrived at your final destination. Quest complete!")
            return false // Finished entirely
        }
        
        let nextDestination = quest.waypoints[currentLegIndex + 1].coordinate
        SpeechService.shared.speak("Arrived at \(quest.waypoints[currentLegIndex].name). Next stop is \(quest.waypoints[currentLegIndex + 1].name). Route is ready when you are.")
        
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
                self.instructions = route.steps.compactMap { step in
                    guard !step.instructions.isEmpty else { return nil }
                    return NavigationInstruction(
                        text: step.instructions,
                        distanceInMeters: Int(step.distance),
                        routeOffsetInMeters: 0, // Simplified for now
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
