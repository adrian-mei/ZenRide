import SwiftUI
import MapKit

private let carChevronImage: UIImage = {
    let size = CGSize(width: 44, height: 44)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let context = ctx.cgContext
        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 8,
                          color: UIColor.black.withAlphaComponent(0.6).cgColor)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: 22, y: 4))
        path.addLine(to: CGPoint(x: 40, y: 38))
        path.addLine(to: CGPoint(x: 22, y: 30))
        path.addLine(to: CGPoint(x: 4, y: 38))
        path.close()
        UIColor.systemBlue.setFill(); path.fill()
        UIColor.white.setStroke(); path.lineWidth = 2.0; path.stroke()
    }
}()

struct ZenMapView: UIViewRepresentable {
    @EnvironmentObject var cameraStore: CameraStore
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var routingService: RoutingService
    @Binding var routeState: RouteState

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        context.coordinator.mapView = mapView

        mapView.showsUserLocation = true
        mapView.showsTraffic = true
        mapView.userTrackingMode = .followWithHeading
        mapView.isPitchEnabled = true

        let hour = Calendar.current.component(.hour, from: Date())
        let isDaytime = hour >= 7 && hour < 18
        mapView.overrideUserInterfaceStyle = isDaytime ? .light : .dark

        let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll
        mapView.preferredConfiguration = config

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        // We want to use our custom car chevron for both simulation AND real navigation.
        // We only show the native GPS dot during search mode.
        let shouldShowNativeGPS = (routeState == .search)
        if uiView.showsUserLocation != shouldShowNativeGPS {
            uiView.showsUserLocation = shouldShowNativeGPS
        }

        // Handle Car Annotation (Simulated OR Real Navigation)
        if routeState == .navigating || owlPolice.isSimulating, let location = owlPolice.currentLocation {
            if coordinator.simulatedCarAnnotation == nil {
                let newCar = SimulatedCarAnnotation(coordinate: location.coordinate)
                coordinator.simulatedCarAnnotation = newCar
                uiView.addAnnotation(newCar)
            } else {
                let duration = owlPolice.isSimulating ? (1.0 / 60.0) : 1.0
                UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                    coordinator.simulatedCarAnnotation?.coordinate = location.coordinate
                }
            }

            // Rotate car chevron — only when bearing changes by more than 2°
            let bearing = location.course >= 0 ? location.course : 0
            if abs(bearing - coordinator.lastBearing) > 2.0 {
                coordinator.lastBearing = bearing
                if let carAnnotation = coordinator.simulatedCarAnnotation,
                   let carView = uiView.view(for: carAnnotation) {
                    let radians = CGFloat(bearing * .pi / 180.0)
                    let duration = owlPolice.isSimulating ? (1.0 / 60.0) : 1.0
                    UIView.animate(withDuration: duration, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                        carView.transform = CGAffineTransform(rotationAngle: radians)
                    }
                }
            }
        } else if routeState == .search, let car = coordinator.simulatedCarAnnotation {
            // Remove the custom car when we go back to search mode
            uiView.removeAnnotation(car)
            coordinator.simulatedCarAnnotation = nil
            coordinator.lastBearing = 0
        }

        // Dynamic 3D camera during navigation (for both real and simulated driving)
        if routeState == .navigating, let location = owlPolice.currentLocation {
            let bearing = location.course >= 0 ? location.course : 0
            let lookAheadCoord = location.coordinate.coordinate(
                offsetBy: 150,
                bearingDegrees: bearing
            )
            let speedMph = max(0, owlPolice.currentSpeedMPH)
            let dynamicDistance = max(500, min(1800, 500 + (speedMph * 25)))
            let dynamicPitch = max(45, min(75, 75 - (speedMph * 0.4)))
            let camera = MKMapCamera(
                lookingAtCenter: lookAheadCoord,
                fromDistance: dynamicDistance,
                pitch: dynamicPitch,
                heading: bearing
            )
            // Use curveLinear animation for real GPS to smoothly interpolate between drops without rubber-banding. Instant for simulation.
            if !owlPolice.isSimulating {
                UIView.animate(withDuration: 1.0, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                    uiView.setCamera(camera, animated: false) // Handled by UIView.animate
                }
            } else {
                uiView.setCamera(camera, animated: false)
            }
        } else if routeState == .search && coordinator.lastRouteState != .search {
            uiView.userTrackingMode = .followWithHeading
            let camera = MKMapCamera(
                lookingAtCenter: uiView.centerCoordinate,
                fromDistance: 10000, pitch: 0, heading: 0
            )
            uiView.setCamera(camera, animated: true)
        }

        // Add any new camera annotations (idempotent — never re-adds existing ones)
        let existingIds = Set(uiView.annotations.compactMap { ($0 as? CameraAnnotation)?.id })
        let newAnnotations = cameraStore.cameras
            .filter { !existingIds.contains($0.id) }
            .map { CameraAnnotation(camera: $0) }
        if !newAnnotations.isEmpty {
            uiView.addAnnotations(newAnnotations)
        }

        // Update destination annotation in-place to avoid flicker
        let destCoord: CLLocationCoordinate2D? = (routeState == .reviewing || routeState == .navigating)
            ? routingService.activeRoute.last : nil
        let existingDest = uiView.annotations.compactMap { $0 as? DestinationAnnotation }.first

        if let destCoord {
            if let existing = existingDest {
                if existing.coordinate.latitude != destCoord.latitude ||
                   existing.coordinate.longitude != destCoord.longitude {
                    existing.coordinate = destCoord
                }
            } else {
                uiView.addAnnotation(DestinationAnnotation(coordinate: destCoord, title: "Destination"))
            }
        } else if let existing = existingDest {
            uiView.removeAnnotation(existing)
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
            let startIndex = routingService.routeProgressIndex
            var route = Array(routingService.activeRoute[startIndex...])

            if routeState == .navigating, let carLoc = owlPolice.currentLocation?.coordinate, route.count > 1 {
                route[0] = carLoc
            }

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
        // Stored in coordinator (class/ref type) to avoid @State re-entrancy in updateUIView
        var simulatedCarAnnotation: SimulatedCarAnnotation?
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

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if annotation is SimulatedCarAnnotation {
                let identifier = "Car"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.layer.shadowColor = UIColor.black.cgColor
                    view?.layer.shadowOpacity = 0.5
                    view?.layer.shadowRadius = 4
                }
                view?.image = carChevronImage
                return view
            }

            if let cameraAnnotation = annotation as? CameraAnnotation {
                let identifier = "Camera"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: cameraAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                } else {
                    annotationView?.annotation = cameraAnnotation
                }
                annotationView?.glyphImage = UIImage(systemName: "camera.fill")
                annotationView?.glyphTintColor = UIColor.black
                annotationView?.markerTintColor = UIColor.systemYellow
                annotationView?.displayPriority = .required
                return annotationView
            }

            if annotation is DestinationAnnotation {
                let identifier = "Destination"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                } else {
                    annotationView?.annotation = annotation
                }
                annotationView?.markerTintColor = UIColor.systemRed
                annotationView?.displayPriority = .required
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
                        renderer.strokeColor = UIColor(red: 0.05, green: 0.35, blue: 0.9, alpha: 1.0)
                        renderer.lineWidth = 16
                    } else {
                        renderer.strokeColor = UIColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 1.0)
                        renderer.lineWidth = 10
                    }
                } else {
                    renderer.strokeColor = UIColor.systemGray3
                    renderer.lineWidth = 10
                }
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }

            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8)
                renderer.lineWidth = 5
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

class DestinationAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    let title: String?

    init(coordinate: CLLocationCoordinate2D, title: String? = nil) {
        self.coordinate = coordinate
        self.title = title
        super.init()
    }
}
