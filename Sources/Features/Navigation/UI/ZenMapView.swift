import SwiftUI
import MapKit
import UIKit

struct ZenMapView: UIViewRepresentable {
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var multiplayerService: MultiplayerService
    @EnvironmentObject var playerStore: PlayerStore
    @Binding var routeState: RouteState
    @Binding var isTracking: Bool
    var mapMode: MapMode = .turnByTurn
    var onMapTap: (() -> Void)? = nil

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView

        mapView.showsUserLocation = true
        mapView.showsTraffic = true
        mapView.userTrackingMode = .followWithHeading
        mapView.isPitchEnabled = true

        // Force LIGHT mode for the cute aesthetic
        mapView.overrideUserInterfaceStyle = .light

        let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = config

        // Register cluster view so MKMapView can render parking pin clusters
        mapView.register(
            MKMarkerAnnotationView.self,
            forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier
        )

        // Add tap gesture recognizer for toggling UI
        let tapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        let shouldShowNativeGPS = (routeState == .search)
        if uiView.showsUserLocation != shouldShowNativeGPS {
            uiView.showsUserLocation = shouldShowNativeGPS
        }

        // Add Cameras
        if coordinator.lastCameraCount != bunnyPolice.cameras.count {
            coordinator.lastCameraCount = bunnyPolice.cameras.count
            let oldCameras = uiView.annotations.compactMap { $0 as? CameraAnnotation }
            uiView.removeAnnotations(oldCameras)
            let newCameras = bunnyPolice.cameras.map { CameraAnnotation(camera: $0) }
            uiView.addAnnotations(newCameras)
        }

        // Handle Multiplayer Friends
        if let session = multiplayerService.activeSession {
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

        // Handle Car Annotation
        if routeState == .navigating || locationProvider.isSimulating, let location = locationProvider.currentLocation {
            let currentType = vehicleStore.selectedVehicle?.type ?? .car

            if coordinator.simulatedCarAnnotation == nil || coordinator.simulatedCarAnnotation?.vehicleType != currentType {
                if let oldCar = coordinator.simulatedCarAnnotation {
                    uiView.removeAnnotation(oldCar)
                }
                let newCar = SimulatedCarAnnotation(coordinate: location.coordinate, vehicleType: currentType)
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

        // Dynamic 3D camera
        if routeState == .navigating, let location = locationProvider.currentLocation, isTracking {
            if mapMode == .turnByTurn {
                let bearing = location.course >= 0 ? location.course : 0
                let speedMph = max(0, locationProvider.currentSpeedMPH)

                let lookAheadMeters = max(40.0, min(500.0, 40.0 + (speedMph * 6.0)))
                let lookAheadCoord = location.coordinate.coordinate(offsetBy: lookAheadMeters, bearingDegrees: bearing)

                var dynamicDistance = max(150, min(3000, 250 + (speedMph * 40)))
                var dynamicPitch: Double
                if speedMph < 10 {
                    dynamicPitch = 15.0 + (speedMph * 2.5)
                } else {
                    dynamicPitch = min(85.0, 40.0 + ((speedMph - 10) * 0.75))
                }

                if !routingService.instructions.isEmpty && routingService.currentInstructionIndex < routingService.instructions.count {
                    let instruction = routingService.instructions[routingService.currentInstructionIndex]
                    let traveled = locationProvider.isSimulating ? locationProvider.distanceTraveledInSimulationMeters : routingService.distanceTraveledMeters
                    let distToTurn = Double(instruction.routeOffsetInMeters) - traveled
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
                if !routingService.activeRoute.isEmpty {
                    let polyline = MKPolyline(coordinates: routingService.activeRoute, count: routingService.activeRoute.count)
                    uiView.setVisibleMapRect(polyline.boundingMapRect, edgePadding: UIEdgeInsets(top: 150, left: 50, bottom: 150, right: 50), animated: true)
                }
            }
        } else if routeState == .search && coordinator.lastRouteState != .search {
            coordinator.is3D = false
            uiView.userTrackingMode = .followWithHeading
            let camera = MKMapCamera(lookingAtCenter: uiView.centerCoordinate, fromDistance: 10000, pitch: 0, heading: 0)
            uiView.setCamera(camera, animated: true)
        }
        coordinator.lastRouteState = routeState

        // Quest Waypoints
        let questCacheKey = "\(routingService.activeQuest?.id.uuidString ?? "no_quest")_\(routingService.currentLegIndex)"
        if coordinator.lastQuestCacheKey != questCacheKey {
            coordinator.lastQuestCacheKey = questCacheKey
            uiView.removeAnnotations(uiView.annotations.filter { $0 is QuestWaypointAnnotation })
            if let quest = routingService.activeQuest {
                let anns = quest.waypoints.enumerated().map { QuestWaypointAnnotation(waypoint: $0.element, index: $0.offset) }
                uiView.addAnnotations(anns)
            }
        }

        // Freeway Entry Icons
        let instructionCount = routingService.instructions.count
        if coordinator.lastInstructionCount != instructionCount && !routingService.activeRoute.isEmpty {
            coordinator.lastInstructionCount = instructionCount
            uiView.removeAnnotations(uiView.annotations.compactMap { $0 as? POIAnnotation }.filter { $0.type == .freeway })
            let freewayAnns: [POIAnnotation] = routingService.instructions.compactMap { inst in
                let msg = inst.text.lowercased()
                guard msg.contains("motorway") || msg.contains("highway") || msg.contains("freeway") else { return nil }
                let idx = min(inst.pointIndex, routingService.activeRoute.count - 1)
                guard idx >= 0 else { return nil }
                return POIAnnotation(coordinate: routingService.activeRoute[idx], title: "Freeway Entry", subtitle: inst.text, type: .freeway)
            }
            uiView.addAnnotations(freewayAnns)
        }

        // Route Overlays
        let overlayKey = "\(routingService.activeRoute.count)_\(routeState.hashValue)"
        if coordinator.lastOverlayCacheKey != overlayKey {
            coordinator.lastOverlayCacheKey = overlayKey
            uiView.removeOverlays(uiView.overlays)
            if routeState == .reviewing {
                for (index, routeCoords) in routingService.activeAlternativeRoutes.enumerated() {
                    if index != routingService.selectedRouteIndex && !routeCoords.isEmpty {
                        let poly = BorderedPolyline(coordinates: routeCoords, count: routeCoords.count)
                        poly.isBorder = true
                        poly.subtitle = "unselected"
                        uiView.addOverlay(poly, level: .aboveRoads)
                    }
                }
            }
            if !routingService.activeRoute.isEmpty {
                let route = routingService.activeRoute
                let outline = BorderedPolyline(coordinates: route, count: route.count)
                outline.isBorder = true
                outline.subtitle = "selected"
                uiView.addOverlay(outline, level: .aboveRoads)
                let inner = BorderedPolyline(coordinates: route, count: route.count)
                inner.isBorder = false
                inner.subtitle = "selected"
                uiView.addOverlay(inner, level: .aboveRoads)
                if routeState == .reviewing {
                    uiView.setVisibleMapRect(inner.boundingMapRect, edgePadding: UIEdgeInsets(top: 80, left: 50, bottom: 150, right: 50), animated: true)
                }
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    // MARK: - Coordinator

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ZenMapView
        var lastOverlayCacheKey = ""
        var lastQuestCacheKey = ""
        var lastBearing = 0.0
        var lastRouteState: RouteState = .search
        var simulatedCarAnnotation: SimulatedCarAnnotation?
        var friendAnnotations: [String: FriendAnnotation] = [:]
        var lastCameraCenter: CLLocationCoordinate2D?
        var lastCameraBearing = 0.0
        var lastCameraDistance = 0.0
        var lastCameraPitch = 0.0
        var lastCameraCount = -1
        var lastInstructionCount = -1
        weak var mapView: MKMapView?
        var lastSearchRegion: MKCoordinateRegion?
        var isSearchingPOIs = false
        var is3D = false

        init(_ parent: ZenMapView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(self, selector: #selector(recenter), name: AppNotification.recenterMap, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(toggle3D(_:)), name: AppNotification.toggle3DMap, object: nil)
        }

        @objc func recenter() { mapView?.userTrackingMode = .followWithHeading }

        @objc func toggle3D(_ notification: Notification) {
            guard let mapView else { return }
            is3D = (notification.object as? Bool) ?? !is3D
            let camera = MKMapCamera(lookingAtCenter: mapView.centerCoordinate, fromDistance: is3D ? 800 : 10000, pitch: is3D ? 60 : 0, heading: mapView.camera.heading)
            mapView.setCamera(camera, animated: true)
            if is3D { mapView.userTrackingMode = .followWithHeading }
        }

        @objc func handleTap(_ gesture: UITapGestureRecognizer) { parent.onMapTap?() }

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            DispatchQueue.main.async { self.parent.isTracking = (mode == .followWithHeading || mode == .follow) }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let current = mapView.region
            if let last = lastSearchRegion {
                let moved = CLLocation(latitude: current.center.latitude, longitude: current.center.longitude)
                    .distance(from: CLLocation(latitude: last.center.latitude, longitude: last.center.longitude))
                if moved < 500 { return }
            }
            guard !isSearchingPOIs else { return }
            isSearchingPOIs = true
            lastSearchRegion = current
            Task {
                await searchPOIs(in: current)
                DispatchQueue.main.async { self.isSearchingPOIs = false }
            }
        }

        private func searchPOIs(in region: MKCoordinateRegion) async {
            let queries: [(String, POIAnnotation.POIType)] = [
                ("Police", .emergency), ("Fire Station", .emergency),
                ("Hospital", .emergency), ("School", .school), ("Park", .park)
            ]
            var newAnns: [POIAnnotation] = []
            for (q, t) in queries {
                let req = MKLocalSearch.Request()
                req.naturalLanguageQuery = q
                req.region = region
                do {
                    let res = try await MKLocalSearch(request: req).start()
                    for item in res.mapItems {
                        newAnns.append(POIAnnotation(coordinate: item.placemark.coordinate, title: item.name, subtitle: q, type: t, mapItem: item))
                    }
                } catch {
                    Log.error("ZenMap", "POI search failed for '\(q)': \(error)")
                }
            }
            await MainActor.run {
                guard let mapView = self.mapView else { return }
                mapView.removeAnnotations(mapView.annotations.compactMap { $0 as? POIAnnotation })
                mapView.addAnnotations(newAnns)
            }
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let poi = view.annotation as? POIAnnotation {
                NotificationCenter.default.post(name: AppNotification.addPOIToRoute, object: poi)
            }
        }

        // MARK: - Annotation Views

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let car = annotation as? SimulatedCarAnnotation {
                let id = "Car_\(car.vehicleType.rawValue)"
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? {
                    let v = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    v.layer.shadowColor = UIColor.black.cgColor
                    v.layer.shadowOpacity = 0.3
                    v.layer.shadowRadius = 4
                    return v
                }()
                v.image = MapVehicleImageRenderer.image(for: car.vehicleType, character: parent.playerStore.selectedCharacter)
                return v
            }

            if let friend = annotation as? FriendAnnotation {
                let id = "Friend"
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? {
                    let v = MKAnnotationView(annotation: annotation, reuseIdentifier: id)
                    v.layer.shadowColor = UIColor.black.cgColor
                    v.layer.shadowOpacity = 0.5
                    v.layer.shadowRadius = 4
                    return v
                }()
                let size = CGSize(width: 40, height: 40)
                v.image = UIGraphicsImageRenderer(size: size).image { _ in
                    UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0).setFill()
                    UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
                    UIColor.white.setStroke()
                    let p = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 36, height: 36))
                    p.lineWidth = 2; p.stroke()
                    let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20)]
                    let s = friend.memberAvatar ?? "🐾"
                    let sz = s.size(withAttributes: attrs)
                    s.draw(at: CGPoint(x: (size.width - sz.width) / 2, y: (size.height - sz.height) / 2), withAttributes: attrs)
                }
                v.transform = CGAffineTransform(rotationAngle: CGFloat(friend.memberHeading * .pi / 180.0))
                return v
            }

            if let wp = annotation as? QuestWaypointAnnotation {
                let id = "QuestWP"
                let v: MKMarkerAnnotationView
                if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView {
                    dequeued.annotation = wp
                    v = dequeued
                } else {
                    v = MKMarkerAnnotationView(annotation: wp, reuseIdentifier: id)
                    v.canShowCallout = true
                }
                let isPast = wp.index <= parent.routingService.currentLegIndex
                let isTarget = wp.index == parent.routingService.currentLegIndex + 1
                v.glyphImage = UIImage(systemName: isPast ? "checkmark" : wp.wp.icon)
                v.glyphTintColor = .white
                if isPast {
                    v.markerTintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                    v.displayPriority = .defaultLow
                } else if isTarget {
                    v.markerTintColor = .systemOrange
                    v.displayPriority = .required
                } else {
                    v.markerTintColor = UIColor(red: 0.83, green: 0.71, blue: 0.51, alpha: 1.0)
                    v.displayPriority = .defaultHigh
                }
                return v
            }

            if let cam = annotation as? CameraAnnotation {
                let id = "Camera"
                let v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                    ?? MKMarkerAnnotationView(annotation: cam, reuseIdentifier: id)
                v.glyphImage = UIImage(systemName: "camera.fill")
                v.markerTintColor = .systemOrange
                return v
            }

            if let poi = annotation as? POIAnnotation {
                let id = "POI_\(poi.type)"
                let v: MKMarkerAnnotationView
                if let dequeued = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView {
                    v = dequeued
                } else {
                    v = MKMarkerAnnotationView(annotation: poi, reuseIdentifier: id)
                    v.canShowCallout = true
                    let btn = UIButton(type: .contactAdd)
                    btn.tintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                    v.rightCalloutAccessoryView = btn
                }
                switch poi.type {
                case .emergency: v.glyphImage = UIImage(systemName: "shield.fill"); v.markerTintColor = .systemBlue
                case .school:    v.glyphImage = UIImage(systemName: "figure.child"); v.markerTintColor = .systemYellow
                case .park:      v.glyphImage = UIImage(systemName: "tree.fill"); v.markerTintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                case .freeway:   v.glyphImage = UIImage(systemName: "car.fill"); v.markerTintColor = .systemBlue
                }
                return v
            }

            return nil
        }

        // MARK: - Overlay Renderer

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            guard let poly = overlay as? BorderedPolyline else {
                return MKOverlayRenderer(overlay: overlay)
            }
            let r = MKPolylineRenderer(polyline: poly)
            if poly.subtitle == "selected" {
                if poly.isBorder {
                    r.strokeColor = UIColor(red: 0.83, green: 0.71, blue: 0.51, alpha: 1.0)
                    r.lineWidth = 14
                } else {
                    r.strokeColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                    r.lineWidth = 8
                    r.lineDashPattern = [12, 8]
                }
            } else {
                r.strokeColor = UIColor.systemGray3.withAlphaComponent(0.6)
                r.lineWidth = 8
            }
            r.lineCap = .round
            r.lineJoin = .round
            return r
        }
    }
}
