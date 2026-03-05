import Foundation
import CoreLocation
import MapKit

class QuestNavigationManager {
    static func generateLegRouting(
        from start: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        transportType: MKDirectionsTransportType = .automobile
    ) async throws -> (activeRoute: [CLLocationCoordinate2D], distanceMeters: Int, timeSeconds: Int, instructions: [NavigationInstruction]) {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: start))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.requestsAlternateRoutes = false
        request.transportType = transportType

        let directions = MKDirections(request: request)
        let response = try await directions.calculate()
        
        guard let route = response.routes.first else {
            throw RoutingError.noData
        }

        let activeRoute = route.polyline.coordinates
        let distanceMeters = Int(route.distance)
        let timeSeconds = Int(route.expectedTravelTime)

        var cumulativeMeters = 0
        let instructions: [NavigationInstruction] = route.steps.compactMap { step in
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

        return (activeRoute, distanceMeters, timeSeconds, instructions)
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