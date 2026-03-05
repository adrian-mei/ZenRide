import Foundation
import MapKit
import SwiftUI

struct MapSynchronizers {
    
    @MainActor
    static func updateCameras(uiView: MKMapView, coordinator: ZenMapView.Coordinator, cameras: [SpeedCamera]) {
        if coordinator.lastCameraCount != cameras.count {
            coordinator.lastCameraCount = cameras.count
            let oldCameras = uiView.annotations.compactMap { $0 as? CameraAnnotation }
            uiView.removeAnnotations(oldCameras)
            let newCameras = cameras.map { CameraAnnotation(camera: $0) }
            uiView.addAnnotations(newCameras)
        }
    }
    
    @MainActor
    static func updateFriends(uiView: MKMapView, coordinator: ZenMapView.Coordinator, session: CampCrewSession?) {
        if let session = session {
            for member in session.members {
                if let existing = coordinator.friendAnnotations[member.id] {
                    UIView.animate(withDuration: 1.0, delay: 0, options: [.curveLinear, .allowUserInteraction]) {
                        existing.coordinate = member.coordinate
                        if let friendView = uiView.view(for: existing) {
                            friendView.transform = CGAffineTransform(rotationAngle: CGFloat(member.heading * .pi / 180.0))
                        }
                    }
                } else {
                    let newAnn = FriendAnnotation(memberId: member.id, memberName: member.name, memberAvatar: member.avatarURL, coordinate: member.coordinate, heading: member.heading)
                    coordinator.friendAnnotations[member.id] = newAnn
                    uiView.addAnnotation(newAnn)
                }
            }
            let currentIDs = Set(session.members.map(\.id))
            let toRemove = coordinator.friendAnnotations.filter { !currentIDs.contains($0.key) }
            for (id, ann) in toRemove {
                uiView.removeAnnotation(ann)
                coordinator.friendAnnotations.removeValue(forKey: id)
            }
        } else if !coordinator.friendAnnotations.isEmpty {
            uiView.removeAnnotations(Array(coordinator.friendAnnotations.values))
            coordinator.friendAnnotations.removeAll()
        }
    }
    
    @MainActor
    static func updateSimulatedCar(
        uiView: MKMapView,
        coordinator: ZenMapView.Coordinator,
        routeState: RouteState,
        location: CLLocation?,
        vehicleMode: VehicleMode,
        isSimulating: Bool
    ) {
        if routeState == .navigating || isSimulating, let location = location {
            if coordinator.simulatedCarAnnotation == nil || coordinator.simulatedCarAnnotation?.vehicleType != vehicleMode {
                if let oldCar = coordinator.simulatedCarAnnotation {
                    uiView.removeAnnotation(oldCar)
                }
                let newCar = SimulatedCarAnnotation(coordinate: location.coordinate, vehicleType: vehicleMode)
                coordinator.simulatedCarAnnotation = newCar
                uiView.addAnnotation(newCar)
            } else {
                UIView.animate(withDuration: 0.15, delay: 0, options: [.curveLinear, .allowUserInteraction]) {
                    coordinator.simulatedCarAnnotation?.coordinate = location.coordinate
                }
            }

            let bearing = location.course >= 0 ? location.course : 0
            if abs(bearing - coordinator.lastBearing) > 1.0 {
                coordinator.lastBearing = bearing
                if let carAnnotation = coordinator.simulatedCarAnnotation,
                   let carView = uiView.view(for: carAnnotation) {
                    let radians = CGFloat(bearing * .pi / 180.0)
                    UIView.animate(withDuration: 0.2, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                        carView.transform = CGAffineTransform(rotationAngle: radians)
                    }
                }
            }
        } else if routeState == .search, let car = coordinator.simulatedCarAnnotation {
            uiView.removeAnnotation(car)
            coordinator.simulatedCarAnnotation = nil
            coordinator.lastBearing = 0
        }
    }
    
    @MainActor
    static func updateParkedCar(uiView: MKMapView, coordinator: ZenMapView.Coordinator, parkedCar: ParkedCar?) {
        if let car = parkedCar {
            if let existing = coordinator.parkedCarAnnotation {
                UIView.animate(withDuration: 0.2) {
                    existing.coordinate = car.coordinate
                }
            } else {
                let newAnn = ParkedCarAnnotation(coordinate: car.coordinate)
                coordinator.parkedCarAnnotation = newAnn
                uiView.addAnnotation(newAnn)
            }
        } else if let existing = coordinator.parkedCarAnnotation {
            uiView.removeAnnotation(existing)
            coordinator.parkedCarAnnotation = nil
        }
    }
    
    @MainActor
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
    
    @MainActor
    static func updateSearchLocationVehicle(
        uiView: MKMapView,
        coordinator: ZenMapView.Coordinator,
        routeState: RouteState,
        location: CLLocation?,
        vehicleMode: VehicleMode,
        character: Character
    ) {
        if routeState == .search, let location = location {
            let bearing = location.course >= 0 ? location.course : 0
            let mapHeading = uiView.camera.heading
            let screenBearing = bearing - mapHeading

            if let userLocationView = uiView.view(for: uiView.userLocation) {
                if coordinator.lastVehicleMode != vehicleMode || coordinator.lastCharacter != character {
                    coordinator.lastVehicleMode = vehicleMode
                    coordinator.lastCharacter = character
                    userLocationView.image = MapVehicleImageRenderer.image(for: vehicleMode, character: character)
                }

                if abs(screenBearing - coordinator.lastBearing) > 1.0 {
                    coordinator.lastBearing = screenBearing
                    let radians = CGFloat(screenBearing * .pi / 180.0)
                    UIView.animate(withDuration: 0.2, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                        userLocationView.transform = CGAffineTransform(rotationAngle: radians)
                    }
                }
            }
        }
    }
    
    @MainActor
    static func updateQuestWaypoints(
        uiView: MKMapView,
        coordinator: ZenMapView.Coordinator,
        activeQuest: DailyQuest?,
        currentLegIndex: Int
    ) {
        let questCacheKey = "\(activeQuest?.id.uuidString ?? "no_quest")_\(currentLegIndex)"
        if coordinator.lastQuestCacheKey != questCacheKey {
            coordinator.lastQuestCacheKey = questCacheKey
            uiView.removeAnnotations(uiView.annotations.filter { $0 is QuestWaypointAnnotation })
            if let quest = activeQuest {
                let anns = quest.waypoints.enumerated().map { QuestWaypointAnnotation(waypoint: $0.element, index: $0.offset) }
                uiView.addAnnotations(anns)
            }
        }
    }
    
    @MainActor
    static func updateFreewayEntryIcons(
        uiView: MKMapView,
        coordinator: ZenMapView.Coordinator,
        instructions: [NavigationInstruction],
        activeRoute: [CLLocationCoordinate2D]
    ) {
        let instructionCount = instructions.count
        if coordinator.lastInstructionCount != instructionCount && !activeRoute.isEmpty {
            coordinator.lastInstructionCount = instructionCount
            uiView.removeAnnotations(uiView.annotations.compactMap { $0 as? POIAnnotation }.filter { $0.type == .freeway })
            let freewayAnns: [POIAnnotation] = instructions.compactMap { inst in
                let msg = inst.text.lowercased()
                guard msg.contains("motorway") || msg.contains("highway") || msg.contains("freeway") else { return nil }
                let idx = min(inst.pointIndex, activeRoute.count - 1)
                guard idx >= 0 else { return nil }
                return POIAnnotation(coordinate: activeRoute[idx], title: "Freeway Entry", subtitle: inst.text, type: .freeway)
            }
            uiView.addAnnotations(freewayAnns)
        }
    }
    
    @MainActor
    static func updateRouteOverlays(
        uiView: MKMapView,
        coordinator: ZenMapView.Coordinator,
        routeState: RouteState,
        activeRoute: [CLLocationCoordinate2D],
        alternativeRoutes: [[CLLocationCoordinate2D]],
        selectedRouteIndex: Int
    ) {
        let overlayKey = "\(activeRoute.count)_\(routeState.hashValue)"
        if coordinator.lastOverlayCacheKey != overlayKey {
            coordinator.lastOverlayCacheKey = overlayKey
            uiView.removeOverlays(uiView.overlays)
            if routeState == .reviewing {
                for (index, routeCoords) in alternativeRoutes.enumerated() {
                    if index != selectedRouteIndex && !routeCoords.isEmpty {
                        let poly = BorderedPolyline(coordinates: routeCoords, count: routeCoords.count)
                        poly.isBorder = true
                        poly.subtitle = "unselected"
                        uiView.addOverlay(poly, level: .aboveRoads)
                    }
                }
            }
            if !activeRoute.isEmpty {
                let outline = BorderedPolyline(coordinates: activeRoute, count: activeRoute.count)
                outline.isBorder = true
                outline.subtitle = "selected"
                uiView.addOverlay(outline, level: .aboveRoads)
                let inner = BorderedPolyline(coordinates: activeRoute, count: activeRoute.count)
                inner.isBorder = false
                inner.subtitle = "selected"
                uiView.addOverlay(inner, level: .aboveRoads)
                if routeState == .reviewing {
                    uiView.setVisibleMapRect(inner.boundingMapRect, edgePadding: UIEdgeInsets(top: 80, left: 50, bottom: 150, right: 50), animated: true)
                }
            }
        }
    }
}
