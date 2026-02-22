import Foundation

let path = "Sources/ZenMapView.swift"
var contents = try! String(contentsOfFile: path, encoding: .utf8)

// 1. Hide GPS when simulating
let oldUpdateStart = """
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Handle Simulated Car Annotation
"""
let newUpdateStart = """
    func updateUIView(_ uiView: MKMapView, context: Context) {
        // Hide GPS dot if simulating
        if uiView.showsUserLocation == owlPolice.isSimulating {
            uiView.showsUserLocation = !owlPolice.isSimulating
        }
        
        // Handle Simulated Car Annotation
"""
contents = contents.replacingOccurrences(of: oldUpdateStart, with: newUpdateStart)


// 2. 3D Look-Ahead Camera
let oldCamera = """
                // Track car with map camera if desired (adds a nice driving feel)
                let camera = MKMapCamera(lookingAtCenter: location.coordinate, fromDistance: 1000, pitch: 45, heading: location.course >= 0 ? location.course : 0)
                uiView.setCamera(camera, animated: true)
"""
let newCamera = """
                // The Apple Maps "Look-Ahead" 3D Camera
                // Calculate a coordinate ahead of the car to keep the puck in the lower third
                let lookAheadCoord = location.coordinate.coordinate(offsetBy: 150, bearingDegrees: location.course >= 0 ? location.course : 0)
                let camera = MKMapCamera(lookingAtCenter: lookAheadCoord, fromDistance: 800, pitch: 65, heading: location.course >= 0 ? location.course : 0)
                uiView.setCamera(camera, animated: true)
"""
contents = contents.replacingOccurrences(of: oldCamera, with: newCamera)


// 3. Apple Maps Double-Bordered Route (Two overlays)
let oldRoute = """
        // Handle Routing Polylines
        let currentOverlays = uiView.overlays
        if routingService.activeRoute.isEmpty {
            uiView.removeOverlays(currentOverlays)
        } else {
            // Check if we already have a polyline for this route to avoid redundant redraws
            if currentOverlays.isEmpty {
                let polyline = MKPolyline(coordinates: routingService.activeRoute, count: routingService.activeRoute.count)
                uiView.addOverlay(polyline)
                
                // Zoom map to fit route
                let rect = polyline.boundingMapRect
                uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 50, left: 50, bottom: 50, right: 50), animated: true)
            }
        }
"""
let newRoute = """
        // Handle Routing Polylines
        let currentOverlays = uiView.overlays
        if routingService.activeRoute.isEmpty {
            uiView.removeOverlays(currentOverlays)
        } else {
            if currentOverlays.isEmpty {
                let route = routingService.activeRoute
                // Add the outer border polyline
                let outlinePolyline = BorderedPolyline(coordinates: route, count: route.count)
                outlinePolyline.isBorder = true
                uiView.addOverlay(outlinePolyline)
                
                // Add the inner vibrant polyline
                let innerPolyline = BorderedPolyline(coordinates: route, count: route.count)
                innerPolyline.isBorder = false
                uiView.addOverlay(innerPolyline)
                
                let rect = innerPolyline.boundingMapRect
                uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 50, bottom: 80, right: 50), animated: true)
            }
        }
"""
contents = contents.replacingOccurrences(of: oldRoute, with: newRoute)


// 4. Update the Simulated Car to a Navigation Chevron
let oldCarGraphic = """
                // Draw a simple car representation
                let carSize = CGSize(width: 30, height: 40)
                UIGraphicsBeginImageContextWithOptions(carSize, false, 0.0)
                if let context = UIGraphicsGetCurrentContext() {
                    // Car body
                    let rect = CGRect(origin: .zero, size: carSize)
                    let path = UIBezierPath(roundedRect: rect, cornerRadius: 8)
                    UIColor.systemBlue.setFill()
                    path.fill()
                    
                    // Windshield
                    let glassRect = CGRect(x: 5, y: 10, width: 20, height: 10)
                    let glassPath = UIBezierPath(roundedRect: glassRect, cornerRadius: 2)
                    UIColor.black.setFill()
                    glassPath.fill()
                    
                    let image = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    view?.image = image
                }
"""

let newCarGraphic = """
                // Draw a Navigation Chevron (Apple Maps style)
                let size = CGSize(width: 44, height: 44)
                UIGraphicsBeginImageContextWithOptions(size, false, 0.0)
                if let context = UIGraphicsGetCurrentContext() {
                    // Drop shadow
                    context.setShadow(offset: CGSize(width: 0, height: 4), blur: 8, color: UIColor.black.withAlphaComponent(0.6).cgColor)
                    
                    let path = UIBezierPath()
                    // Draw arrowhead pointing up
                    path.move(to: CGPoint(x: 22, y: 4))      // Top tip
                    path.addLine(to: CGPoint(x: 40, y: 38))  // Bottom right
                    path.addLine(to: CGPoint(x: 22, y: 30))  // Inner notch
                    path.addLine(to: CGPoint(x: 4, y: 38))   // Bottom left
                    path.close()
                    
                    // Neon glowing accent
                    UIColor.systemBlue.setFill()
                    path.fill()
                    
                    UIColor.white.setStroke()
                    path.lineWidth = 2.0
                    path.stroke()
                    
                    let image = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    view?.image = image
                }
"""
contents = contents.replacingOccurrences(of: oldCarGraphic, with: newCarGraphic)


// 5. Add custom Polyline and Renderer for the border
let customPolyline = """
class BorderedPolyline: MKPolyline {
    var isBorder: Bool = false
}

class SimulatedCarAnnotation: NSObject, MKAnnotation {
"""
contents = contents.replacingOccurrences(of: "class SimulatedCarAnnotation: NSObject, MKAnnotation {", with: customPolyline)

let oldRenderer = """
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = UIColor.systemBlue
                renderer.lineWidth = 5
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
"""
let newRenderer = """
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let polyline = overlay as? BorderedPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                if polyline.isBorder {
                    // Outer dark border/shadow
                    renderer.strokeColor = UIColor.black.withAlphaComponent(0.8)
                    renderer.lineWidth = 10
                } else {
                    // Inner vibrant route line
                    renderer.strokeColor = UIColor.systemBlue
                    renderer.lineWidth = 6
                }
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
"""
contents = contents.replacingOccurrences(of: oldRenderer, with: newRenderer)


try! contents.write(toFile: path, atomically: true, encoding: .utf8)
print("Updated ZenMapView.swift with Apple Maps experience.")
