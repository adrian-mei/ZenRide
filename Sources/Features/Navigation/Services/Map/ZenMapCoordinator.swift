import Foundation
import MapKit
import SwiftUI

@MainActor
class ZenMapCoordinator: NSObject, MKMapViewDelegate {
    var parent: ZenMapView
    var lastOverlayCacheKey = ""
    var lastQuestCacheKey = ""
    var lastBearing = 0.0
    var lastRouteState: RouteState = .search
    var simulatedCarAnnotation: SimulatedCarAnnotation?
    var parkedCarAnnotation: ParkedCarAnnotation?
    var friendAnnotations: [String: FriendAnnotation] = [:]
    var lastCameraCenter: CLLocationCoordinate2D?
    var lastCameraBearing = 0.0
    var lastCameraDistance = 0.0
    var lastCameraPitch = 0.0
    var lastCameraCount = -1
    var lastInstructionCount = -1
    var lastVehicleMode: VehicleMode?
    var lastCharacter: Character?
    weak var mapView: MKMapView?
    var lastSearchRegion: MKCoordinateRegion?
    var isSearchingPOIs = false
    var is3D = false
    private let poiSearchService = POISearchService()

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

    nonisolated func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
        Task { @MainActor in
            if parent.routeState == .search, let location = userLocation.location {
                let bearing = location.course >= 0 ? location.course : 0
                let screenBearing = bearing - mapView.camera.heading
                if let view = mapView.view(for: userLocation) {
                    let radians = CGFloat(screenBearing * .pi / 180.0)
                    UIView.animate(withDuration: 0.2, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
                        view.transform = CGAffineTransform(rotationAngle: radians)
                    }
                }
            }
        }
    }

    nonisolated func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
        Task { @MainActor in
            self.parent.isTracking = (mode == .followWithHeading || mode == .follow)
        }
    }

    nonisolated func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
        Task { @MainActor in
            if parent.routeState == .search, let location = mapView.userLocation.location {
                let bearing = location.course >= 0 ? location.course : 0
                let screenBearing = bearing - mapView.camera.heading

                if let view = mapView.view(for: mapView.userLocation) {
                    let radians = CGFloat(screenBearing * .pi / 180.0)
                    view.transform = CGAffineTransform(rotationAngle: radians)
                }
            }
        }
    }

    nonisolated func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        Task { @MainActor in
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
                self.isSearchingPOIs = false
            }
        }
    }

    private func searchPOIs(in region: MKCoordinateRegion) async {
        let newAnns = await poiSearchService.searchPOIs(in: region)
        guard let mapView = self.mapView else { return }
        mapView.removeAnnotations(mapView.annotations.compactMap { $0 as? POIAnnotation })
        mapView.addAnnotations(newAnns)
    }

    nonisolated func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        Task { @MainActor in
            if let poi = view.annotation as? POIAnnotation {
                NotificationCenter.default.post(name: AppNotification.addPOIToRoute, object: poi)
            }
        }
    }

    // MARK: - Annotation Views

    nonisolated func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        // We have to access parent state so we dispatch to main safely, but viewFor needs to return synchronously.
        // In real apps, this is called on main thread anyway by MKMapView.
        // We can safely assume we're on main here.
        var result: MKAnnotationView? = nil
        DispatchQueue.main.sync {
            let context = MapAnnotationStoreContext(
                vehicleMode: parent.vehicleStore.selectedVehicle?.type ?? .car,
                character: parent.playerStore.selectedCharacter,
                currentLegIndex: parent.routingService.questManager.currentLegIndex
            )

            if let v = MapAnnotationViewFactory.view(for: annotation, in: mapView, storeContext: context) {
                // Handle caching updates for user location
                if annotation is MKUserLocation {
                    if self.lastVehicleMode != context.vehicleMode || self.lastCharacter != context.character {
                        self.lastVehicleMode = context.vehicleMode
                        self.lastCharacter = context.character
                    }
                }
                result = v
            }
        }
        return result
    }

    // MARK: - Overlay Renderer

    nonisolated func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        guard let poly = overlay as? BorderedPolyline else {
            return MKOverlayRenderer(overlay: overlay)
        }
        let r = MKPolylineRenderer(polyline: poly)
        if poly.subtitle == "selected" {
            if poly.isBorder {
                r.strokeColor = UIColor(red: 0.1, green: 0.3, blue: 0.7, alpha: 1.0)
                r.lineWidth = 18
            } else {
                r.strokeColor = UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 1.0)
                r.lineWidth = 10
            }
        } else {
            r.strokeColor = UIColor.systemGray3.withAlphaComponent(0.6)
            r.lineWidth = 10
        }
        r.lineCap = .round
        r.lineJoin = .round
        return r
    }
}
