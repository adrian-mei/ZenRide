import SwiftUI
import MapKit

private let carChevronImage: UIImage = {
    let size = CGSize(width: 44, height: 44)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let context = ctx.cgContext
        context.setShadow(offset: CGSize(width: 0, height: 2), blur: 4,
                          color: UIColor.black.withAlphaComponent(0.3).cgColor)
        
        let path = UIBezierPath()
        
        // A cute, rounded 3D van/car shape for the Animal Crossing look
        path.move(to: CGPoint(x: 22, y: 6)) // Top tip (nose)
        path.addLine(to: CGPoint(x: 36, y: 34)) // Bottom right
        path.addLine(to: CGPoint(x: 22, y: 28)) // Inner indent
        path.addLine(to: CGPoint(x: 8, y: 34))  // Bottom left
        path.close()
        
        // Cute green body
        UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0).setFill()
        path.fill()
        
        // White stroke outlining the car
        UIColor.white.setStroke()
        path.lineWidth = 3.0
        path.stroke()
    }
}()

struct ZenMapView: UIViewRepresentable {
    @EnvironmentObject var cameraStore: CameraStore
    @EnvironmentObject var parkingStore: ParkingStore
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    @Binding var routeState: RouteState
    @Binding var isTracking: Bool
    var mapMode: MapMode = .turnByTurn // Defaults to 3D driving
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

        // Handle Car Annotation (Simulated OR Real Navigation)
        if routeState == .navigating || locationProvider.isSimulating, let location = locationProvider.currentLocation {
            if coordinator.simulatedCarAnnotation == nil {
                let newCar = SimulatedCarAnnotation(coordinate: location.coordinate)
                coordinator.simulatedCarAnnotation = newCar
                uiView.addAnnotation(newCar)
            } else {
                if locationProvider.isSimulating {
                    coordinator.simulatedCarAnnotation?.coordinate = location.coordinate
                } else {
                    UIView.animate(withDuration: 1.0, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                        coordinator.simulatedCarAnnotation?.coordinate = location.coordinate
                    }
                }
            }

            // Rotate car chevron — only when bearing changes by more than 2°
            let bearing = location.course >= 0 ? location.course : 0
            if abs(bearing - coordinator.lastBearing) > 2.0 {
                coordinator.lastBearing = bearing
                if let carAnnotation = coordinator.simulatedCarAnnotation,
                   let carView = uiView.view(for: carAnnotation) {
                    let radians = CGFloat(bearing * .pi / 180.0)
                    if locationProvider.isSimulating {
                        carView.transform = CGAffineTransform(rotationAngle: radians)
                    } else {
                        UIView.animate(withDuration: 1.0, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                            carView.transform = CGAffineTransform(rotationAngle: radians)
                        }
                    }
                }
            }
        } else if routeState == .search, let car = coordinator.simulatedCarAnnotation {
            // Remove the custom car when we go back to search mode
            uiView.removeAnnotation(car)
            coordinator.simulatedCarAnnotation = nil
            coordinator.lastBearing = 0
        }

        // Dynamic 3D camera during navigation
        if routeState == .navigating, let location = locationProvider.currentLocation {
            if mapMode == .turnByTurn {
                let bearing = location.course >= 0 ? location.course : 0
                let speedMph = max(0, locationProvider.currentSpeedMPH)
                
                let lookAheadMeters = max(50.0, min(400.0, 50.0 + (speedMph * 5.0)))
                let lookAheadCoord = location.coordinate.coordinate(
                    offsetBy: lookAheadMeters,
                    bearingDegrees: bearing
                )
                
                var dynamicDistance = max(200, min(2500, 300 + (speedMph * 35)))
                
                var dynamicPitch: Double
                if speedMph < 15 {
                    dynamicPitch = 20.0 + (speedMph * 2.0)
                } else {
                    dynamicPitch = min(80.0, 50.0 + ((speedMph - 15) * 0.8))
                }
                
                if !routingService.instructions.isEmpty && routingService.currentInstructionIndex < routingService.instructions.count {
                    let currentInstruction = routingService.instructions[routingService.currentInstructionIndex]
                    let traveledForZoom = locationProvider.isSimulating ? locationProvider.distanceTraveledInSimulationMeters : routingService.distanceTraveledMeters
                    let distToTurn = Double(currentInstruction.routeOffsetInMeters) - traveledForZoom
                    let distToTurnFt = distToTurn * 3.28084
                    
                    if distToTurnFt > 0 && distToTurnFt < 500 {
                        let junctionZoomFactor = 1.0 - (distToTurnFt / 500.0)
                        dynamicDistance = dynamicDistance - ((dynamicDistance - 300.0) * junctionZoomFactor)
                        dynamicPitch = dynamicPitch - ((dynamicPitch - 30.0) * junctionZoomFactor)
                    }
                }
                
                // Only update camera if changed significantly to prevent MKMapView lag
                let currentCenter = lookAheadCoord
                let lastCenter = coordinator.lastCameraCenter ?? currentCenter
                let centerDistance = CLLocation(latitude: currentCenter.latitude, longitude: currentCenter.longitude)
                    .distance(from: CLLocation(latitude: lastCenter.latitude, longitude: lastCenter.longitude))
                
                let bearingDiff = abs(bearing - coordinator.lastCameraBearing)
                
                if centerDistance > 1.0 || bearingDiff > 1.0 || abs(dynamicDistance - coordinator.lastCameraDistance) > 10.0 || abs(dynamicPitch - coordinator.lastCameraPitch) > 1.0 || coordinator.lastCameraCenter == nil {
                    
                    coordinator.lastCameraCenter = currentCenter
                    coordinator.lastCameraBearing = bearing
                    coordinator.lastCameraDistance = dynamicDistance
                    coordinator.lastCameraPitch = dynamicPitch
                    
                    let camera = MKMapCamera(
                        lookingAtCenter: lookAheadCoord,
                        fromDistance: dynamicDistance,
                        pitch: dynamicPitch,
                        heading: bearing
                    )
                    
                    if !locationProvider.isSimulating {
                        UIView.animate(withDuration: 1.0, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                            uiView.setCamera(camera, animated: false)
                        }
                    } else {
                        uiView.setCamera(camera, animated: false)
                    }
                }
            } else {
                // Overview Mode - Show the entire route from top down
                if !routingService.activeRoute.isEmpty {
                    let innerPolyline = MKPolyline(coordinates: routingService.activeRoute, count: routingService.activeRoute.count)
                    let rect = innerPolyline.boundingMapRect
                    uiView.setVisibleMapRect(
                        rect,
                        edgePadding: UIEdgeInsets(top: 150, left: 50, bottom: 150, right: 50),
                        animated: true
                    )
                }
            }
        } else if routeState == .search && coordinator.lastRouteState != .search {
            uiView.userTrackingMode = .followWithHeading
            let camera = MKMapCamera(
                lookingAtCenter: uiView.centerCoordinate,
                fromDistance: 10000, pitch: 0, heading: 0
            )
            uiView.setCamera(camera, animated: true)
        }

        // Add Quest Waypoints
        if let quest = routingService.activeQuest {
            let existingQuestIds = Set(uiView.annotations.compactMap { ($0 as? QuestWaypointAnnotation)?.id })
            let newWaypoints = quest.waypoints
                .filter { !existingQuestIds.contains($0.id) }
                .map { QuestWaypointAnnotation(waypoint: $0) }
            if !newWaypoints.isEmpty {
                uiView.addAnnotations(newWaypoints)
            }
        } else {
            // Clean up quest annotations when quest ends
            let toRemove = uiView.annotations.filter { $0 is QuestWaypointAnnotation }
            if !toRemove.isEmpty { uiView.removeAnnotations(toRemove) }
        }

        // Only redraw overlays when route or state actually changes
        let cacheKey = "\(routingService.activeRoute.count)_\(routeState.hashValue)"
        guard coordinator.lastOverlayCacheKey != cacheKey else { return }
        coordinator.lastOverlayCacheKey = cacheKey

        uiView.removeOverlays(uiView.overlays)

        if routeState == .reviewing {
            for (index, routeCoords) in routingService.activeAlternativeRoutes.enumerated() {
                if index != routingService.selectedRouteIndex && !routeCoords.isEmpty {
                    let polyline = BorderedPolyline(coordinates: routeCoords, count: routeCoords.count)
                    polyline.isBorder = true
                    polyline.subtitle = "unselected"
                    uiView.addOverlay(polyline, level: .aboveRoads)
                }
            }
        }

        if !routingService.activeRoute.isEmpty {
            let route = routingService.activeRoute

            let outlinePolyline = BorderedPolyline(coordinates: route, count: route.count)
            outlinePolyline.isBorder = true
            outlinePolyline.subtitle = "selected"
            uiView.addOverlay(outlinePolyline, level: .aboveRoads)

            let innerPolyline = BorderedPolyline(coordinates: route, count: route.count)
            innerPolyline.isBorder = false
            innerPolyline.subtitle = "selected"
            uiView.addOverlay(innerPolyline, level: .aboveRoads)

            if routeState == .reviewing {
                let rect = innerPolyline.boundingMapRect
                uiView.setVisibleMapRect(
                    rect,
                    edgePadding: UIEdgeInsets(top: 80, left: 50, bottom: 150, right: 50),
                    animated: true
                )
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ZenMapView
        var lastOverlayCacheKey: String = ""
        var lastBearing: Double = 0
        var lastRouteState: RouteState = .search
        var parkingAnnotationsLoaded = false
        var simulatedCarAnnotation: SimulatedCarAnnotation?
        
        var lastCameraCenter: CLLocationCoordinate2D? = nil
        var lastCameraBearing: Double = 0
        var lastCameraDistance: Double = 0
        var lastCameraPitch: Double = 0
        
        weak var mapView: MKMapView?

        init(_ parent: ZenMapView) {
            self.parent = parent
            super.init()
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(recenter),
                name: NSNotification.Name("RecenterMap"),
                object: nil
            )
        }

        @objc func recenter() {
            mapView?.userTrackingMode = .followWithHeading
        }
        
        @objc func handleTap(_ gesture: UITapGestureRecognizer) {
            parent.onMapTap?()
        }

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            DispatchQueue.main.async {
                self.parent.isTracking = (mode == .followWithHeading || mode == .follow)
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if annotation is SimulatedCarAnnotation {
                let identifier = "Car"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.layer.shadowColor = UIColor.black.cgColor
                    view?.layer.shadowOpacity = 0.3
                    view?.layer.shadowRadius = 4
                }
                view?.image = carChevronImage
                return view
            }

            if let wpAnnotation = annotation as? QuestWaypointAnnotation {
                let identifier = "QuestWP"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: wpAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = wpAnnotation
                }
                annotationView?.glyphImage = UIImage(systemName: wpAnnotation.wp.icon)
                annotationView?.glyphTintColor = UIColor.white
                annotationView?.markerTintColor = UIColor(red: 0.83, green: 0.71, blue: 0.51, alpha: 1.0) // Wood tan
                annotationView?.displayPriority = .required
                return annotationView
            }

            if let cameraAnnotation = annotation as? CameraAnnotation {
                let identifier = "Camera"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: cameraAnnotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = cameraAnnotation
                }
                annotationView?.glyphImage = UIImage(systemName: "camera.fill")
                annotationView?.markerTintColor = UIColor.systemOrange
                return annotationView
            }

            return nil
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let borderedPolyline = overlay as? BorderedPolyline {
                let renderer = MKPolylineRenderer(polyline: borderedPolyline)
                let isSelected = borderedPolyline.subtitle == "selected"
                if isSelected {
                    if borderedPolyline.isBorder {
                        renderer.strokeColor = UIColor(red: 0.83, green: 0.71, blue: 0.51, alpha: 1.0) // Wood tan border
                        renderer.lineWidth = 14
                    } else {
                        renderer.strokeColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0) // Leaf green center
                        renderer.lineWidth = 8
                        // Make it look like a dotted/dashed hiking trail
                        renderer.lineDashPattern = [12, 8]
                    }
                } else {
                    renderer.strokeColor = UIColor.systemGray3.withAlphaComponent(0.6)
                    renderer.lineWidth = 8
                }
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }

            return MKOverlayRenderer(overlay: overlay)
        }
    }
}

class BorderedPolyline: MKPolyline {
    var isBorder: Bool = false
}

class SimulatedCarAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D

    init(coordinate: CLLocationCoordinate2D) {
        self.coordinate = coordinate
        super.init()
    }
}

class QuestWaypointAnnotation: NSObject, MKAnnotation {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let wp: QuestWaypoint

    init(waypoint: QuestWaypoint) {
        self.id = waypoint.id
        self.wp = waypoint
        self.coordinate = waypoint.coordinate
        self.title = waypoint.name
        super.init()
    }
}

class CameraAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(camera: SpeedCamera) {
        self.id = camera.id
        self.coordinate = CLLocationCoordinate2D(latitude: camera.lat, longitude: camera.lng)
        self.title = "Speed Camera"
        self.subtitle = "Speed Limit: \(camera.speed_limit_mph) MPH"
        super.init()
    }
}
