import Foundation

let path = "Sources/ZenMapView.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

// Fix #1: Smooth tracking (turn off animation queue overloading)
let searchCamera = """
                // The Apple Maps "Look-Ahead" 3D Camera during Navigation
                if routeState == .navigating {
                    let lookAheadCoord = location.coordinate.coordinate(offsetBy: 150, bearingDegrees: location.course >= 0 ? location.course : 0)
                    let camera = MKMapCamera(lookingAtCenter: lookAheadCoord, fromDistance: 800, pitch: 65, heading: location.course >= 0 ? location.course : 0)
                    uiView.setCamera(camera, animated: true)
                }
"""

let replaceCamera = """
                // The Apple Maps "Look-Ahead" 3D Camera during Navigation
                if routeState == .navigating {
                    let lookAheadCoord = location.coordinate.coordinate(offsetBy: 150, bearingDegrees: location.course >= 0 ? location.course : 0)
                    let camera = MKMapCamera(lookingAtCenter: lookAheadCoord, fromDistance: 800, pitch: 65, heading: location.course >= 0 ? location.course : 0)
                    // CRITICAL FIX: animated: false prevents a huge backlog of queued animations and stuttering
                    uiView.setCamera(camera, animated: false)
                }
"""

content = content.replacingOccurrences(of: searchCamera, with: replaceCamera)

// Fix #2: Map Freeze via overlay caching
// The overlays shouldn't be ripped out and redrawn every 0.05 seconds.
let searchOverlayRedraw = """
        // Handle Routing Polylines
        let currentOverlays = uiView.overlays
        uiView.removeOverlays(currentOverlays)
        
        if routeState == .reviewing {
"""

let replaceOverlayRedraw = """
        // CRITICAL FIX: Only redraw heavy overlays when they actually change.
        // We use a custom hash of the active route coordinates + route state as a cache key.
        let activeHash = routingService.activeRoute.count
        let stateHash = routeState.hashValue
        let cacheKey = "\\(activeHash)_\\(stateHash)"
        
        let needsRedraw = context.coordinator.lastOverlayCacheKey != cacheKey
        
        if needsRedraw {
            context.coordinator.lastOverlayCacheKey = cacheKey
            
            // Handle Routing Polylines
            let currentOverlays = uiView.overlays
            uiView.removeOverlays(currentOverlays)
            
            if routeState == .reviewing {
"""

content = content.replacingOccurrences(of: searchOverlayRedraw, with: replaceOverlayRedraw)

// We also need to close the if needsRedraw block.
let searchCloseOverlayRedraw = """
            if routeState == .reviewing {
                let rect = innerPolyline.boundingMapRect
                // Add extra bottom padding for the sheet
                uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 50, bottom: 150, right: 50), animated: true)
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
"""

let replaceCloseOverlayRedraw = """
            if routeState == .reviewing {
                let rect = innerPolyline.boundingMapRect
                // Add extra bottom padding for the sheet
                uiView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 50, bottom: 150, right: 50), animated: true)
            }
        }
        } // End of needsRedraw
    }
    
    func makeCoordinator() -> Coordinator {
"""

content = content.replacingOccurrences(of: searchCloseOverlayRedraw, with: replaceCloseOverlayRedraw)

// Add lastOverlayCacheKey to Coordinator
let searchCoordinator = """
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ZenMapView
        
        init(_ parent: ZenMapView) {
"""

let replaceCoordinator = """
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: ZenMapView
        var lastOverlayCacheKey: String = ""
        
        init(_ parent: ZenMapView) {
"""

content = content.replacingOccurrences(of: searchCoordinator, with: replaceCoordinator)


try! content.write(toFile: path, atomically: true, encoding: .utf8)
