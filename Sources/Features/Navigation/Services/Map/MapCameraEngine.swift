import Foundation
import MapKit
import CoreLocation

@MainActor
enum MapCameraEngine {
    static func updateDynamicCamera(
        uiView: MKMapView,
        coordinator: ZenMapView.Coordinator,
        routeState: RouteState,
        mapMode: MapMode,
        location: CLLocation?,
        isTracking: Bool,
        speedMph: Double,
        instructions: [NavigationInstruction],
        instructionIndex: Int,
        activeRoute: [CLLocationCoordinate2D],
        distanceTraveled: Double
    ) {
        if routeState == .navigating, let location = location, isTracking {
            if mapMode == .turnByTurn {
                let bearing = location.course >= 0 ? location.course : 0
                let safeSpeed = max(0, speedMph)

                let lookAheadMeters = max(40.0, min(500.0, 40.0 + (safeSpeed * 6.0)))
                let lookAheadCoord = location.coordinate.coordinate(offsetBy: lookAheadMeters, bearingDegrees: bearing)

                var dynamicDistance = max(150, min(3000, 250 + (safeSpeed * 40)))
                var dynamicPitch: Double
                if safeSpeed < 10 {
                    dynamicPitch = 15.0 + (safeSpeed * 2.5)
                } else {
                    dynamicPitch = min(85.0, 40.0 + ((safeSpeed - 10) * 0.75))
                }

                if !instructions.isEmpty && instructionIndex < instructions.count {
                    let instruction = instructions[instructionIndex]
                    let distToTurn = Double(instruction.routeOffsetInMeters) - distanceTraveled
                    let distToTurnFt = distToTurn * Constants.metersToFeet
                    if distToTurnFt > 0 && distToTurnFt < 600 {
                        let factor = 1.0 - (distToTurnFt / 600.0)
                        dynamicDistance -= (dynamicDistance - 250.0) * factor
                        dynamicPitch -= (dynamicPitch - 35.0) * factor
                    }
                }

                let currentCenter = lookAheadCoord
                let lastCenter = coordinator.lastCameraCenter ?? currentCenter
                let centerDistance = currentCenter.distance(to: lastCenter)
                let bearingDiff = abs(bearing - coordinator.lastCameraBearing)
                let wrappedBearingDiff = bearingDiff > 180 ? 360 - bearingDiff : bearingDiff

                if coordinator.lastCameraCenter == nil || centerDistance > 0.5 || wrappedBearingDiff > 0.5 || abs(dynamicDistance - coordinator.lastCameraDistance) > 5.0 || abs(dynamicPitch - coordinator.lastCameraPitch) > 0.5 {
                    coordinator.lastCameraCenter = currentCenter
                    coordinator.lastCameraBearing = bearing
                    coordinator.lastCameraDistance = dynamicDistance
                    coordinator.lastCameraPitch = dynamicPitch
                    let camera = MKMapCamera(lookingAtCenter: lookAheadCoord, fromDistance: dynamicDistance, pitch: dynamicPitch, heading: bearing)
                    uiView.setCamera(camera, animated: true)
                }
            } else {
                if !activeRoute.isEmpty {
                    let polyline = MKPolyline(coordinates: activeRoute, count: activeRoute.count)
                    uiView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 150, left: 50, bottom: 150, right: 50), animated: true)
                }
            }
        } else if routeState == .search && coordinator.lastRouteState != .search {
            coordinator.is3D = false
            uiView.userTrackingMode = .followWithHeading
            let camera = MKMapCamera(lookingAtCenter: uiView.centerCoordinate, fromDistance: 10000, pitch: 0, heading: 0)
            uiView.setCamera(camera, animated: true)
        }
    }
}
