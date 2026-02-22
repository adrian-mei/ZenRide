import SwiftUI
import MapKit

struct ZenMapView: UIViewRepresentable {
    @EnvironmentObject var cameraStore: CameraStore
    @EnvironmentObject var owlPolice: OwlPolice
    @EnvironmentObject var routingService: RoutingService
    @Binding var routeState: RouteState
    
    @State private var simulatedCarAnnotation: SimulatedCarAnnotation?
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        
        mapView.showsUserLocation = true
        mapView.showsTraffic = true
        mapView.userTrackingMode = .followWithHeading // Better for driving apps
        mapView.isPitchEnabled = true
        
        // Dynamic High-Contrast Style for Day/Night based on current time
        let hour = Calendar.current.component(.hour, from: Date())
        let isDaytime = hour >= 7 && hour < 18
        mapView.overrideUserInterfaceStyle = isDaytime ? .light : .dark
        
        // Use modern configurations for iOS 16+
        let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
        config.pointOfInterestFilter = .excludingAll // Remove clutter
        mapView.preferredConfiguration = config
        
        return mapView
    }
    
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Hide GPS dot if simulating
        if uiView.showsUserLocation == owlPolice.isSimulating {
            uiView.showsUserLocation = !owlPolice.isSimulating
        }
        
        // Handle Simulated Car Annotation
        if owlPolice.isSimulating, let location = owlPolice.currentLocation {
            DispatchQueue.main.async {
                if simulatedCarAnnotation == nil {
                    let newCar = SimulatedCarAnnotation(coordinate: location.coordinate)
                    simulatedCarAnnotation = newCar
                    uiView.addAnnotation(newCar)
                } else {
                    UIView.animate(withDuration: 0.1) {
                        simulatedCarAnnotation?.coordinate = location.coordinate
                    }
                }
                
                // The Apple Maps "Look-Ahead" 3D Camera during Navigation
                if routeState == .navigating {
                    let lookAheadCoord = location.coordinate.coordinate(offsetBy: 150, bearingDegrees: location.course >= 0 ? location.course : 0)
                    
                    // Dynamic Map Zoom based on speed for hands-free driving
                    let speedMph = max(0, owlPolice.currentSpeedMPH)
                    let dynamicDistance = max(500, min(1800, 500 + (speedMph * 25))) // Zoom out at higher speeds
                    let dynamicPitch = max(45, min(75, 75 - (speedMph * 0.4))) // Flatter pitch at high speeds
                    
                    let camera = MKMapCamera(lookingAtCenter: lookAheadCoord, fromDistance: dynamicDistance, pitch: dynamicPitch, heading: location.course >= 0 ? location.course : 0)
                    // CRITICAL FIX: animated: false prevents a huge backlog of queued animations and stuttering
                    uiView.setCamera(camera, animated: false)
                }
            }
        } else if !owlPolice.isSimulating, let car = simulatedCarAnnotation {
            DispatchQueue.main.async {
                uiView.removeAnnotation(car)
                simulatedCarAnnotation = nil
                
                if routeState == .search {
                    // Return to normal 2D view pointing north when stopping simulation
                    let camera = MKMapCamera(lookingAtCenter: uiView.centerCoordinate, fromDistance: 10000, pitch: 0, heading: 0)
                    uiView.setCamera(camera, animated: true)
                }
            }
        }
        
        // Add camera annotations
        let existingIds = uiView.annotations.compactMap { ($0 as? CameraAnnotation)?.id }
        let newAnnotations = cameraStore.cameras.filter { !existingIds.contains($0.id) }.map {
            CameraAnnotation(camera: $0)
        }
        if !newAnnotations.isEmpty {
            uiView.addAnnotations(newAnnotations)
        }
        
        // Add Destination Annotation
        let destAnnotations = uiView.annotations.compactMap { $0 as? DestinationAnnotation }
        uiView.removeAnnotations(destAnnotations)
        
        if (routeState == .reviewing || routeState == .navigating), let destCoord = routingService.activeRoute.last {
            let destAnnotation = DestinationAnnotation(coordinate: destCoord, title: "Destination")
            uiView.addAnnotation(destAnnotation)
        }
        
        // CRITICAL FIX: Only redraw heavy overlays when they actually change.
        // We use a custom hash of the active route coordinates + route state as a cache key.
        let activeHash = routingService.activeRoute.count
        let stateHash = routeState.hashValue
        let cacheKey = "\(activeHash)_\(stateHash)"
        
        let needsRedraw = context.coordinator.lastOverlayCacheKey != cacheKey
        
        if needsRedraw {
            context.coordinator.lastOverlayCacheKey = cacheKey
            
            // Handle Routing Polylines
            let currentOverlays = uiView.overlays
            uiView.removeOverlays(currentOverlays)
            
            if routeState == .reviewing {
            // Draw all alternative routes first (in gray)
            for (index, routeCoords) in routingService.activeAlternativeRoutes.enumerated() {
                if index != routingService.selectedRouteIndex && !routeCoords.isEmpty {
                    let polyline = BorderedPolyline(coordinates: routeCoords, count: routeCoords.count)
                    polyline.isBorder = true // We use the border hack to pass state to the renderer
                    // We'll use subtitle to hack passing the selection state to the coordinator
                    polyline.subtitle = "unselected"
                    uiView.addOverlay(polyline)
                }
            }
        }
        
        // Draw the active/selected route on top
        if !routingService.activeRoute.isEmpty {
            let route = routingService.activeRoute
            
            // Outer border
            let outlinePolyline = BorderedPolyline(coordinates: route, count: route.count)
            outlinePolyline.isBorder = true
            outlinePolyline.subtitle = "selected"
            uiView.addOverlay(outlinePolyline)
            
            // Inner vibrant line
            let innerPolyline = BorderedPolyline(coordinates: route, count: route.count)
            innerPolyline.isBorder = false
            innerPolyline.subtitle = "selected"
            uiView.addOverlay(innerPolyline)
            
            // Frame the route if we are reviewing
            if routeState == .reviewing {
                let rect = innerPolyline.boundingMapRect
                // Add extra bottom padding for the sheet
                uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 50, bottom: 150, right: 50), animated: true)
            }
        }
        } // End of needsRedraw
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ZenMapView
        var lastOverlayCacheKey: String = ""
        
        init(_ parent: ZenMapView) {
            self.parent = parent
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
                
                view?.image = UIImage(systemName: "location.north.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold))?.withTintColor(.systemBlue, renderingMode: .alwaysOriginal)
                
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
                        renderer.strokeColor = UIColor.systemBlue.withAlphaComponent(0.8) // Dark outline
                        renderer.lineWidth = 16
                    } else {
                        // High contrast cyan/blue for selected route
                        renderer.strokeColor = UIColor(red: 0.1, green: 0.5, blue: 1.0, alpha: 1.0)
                        renderer.lineWidth = 10
                    }
                } else {
                    // Unselected alternative routes
                    renderer.strokeColor = UIColor.systemGray3
                    renderer.lineWidth = 10
                }
                
                // Round ends like Apple Maps
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            
            // Fallback for regular MKPolyline
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

// Subclass to help pass state to the MKOverlayRenderer
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
