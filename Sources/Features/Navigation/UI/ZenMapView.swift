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
    @EnvironmentObject var parkedCarStore: ParkedCarStore
    @Binding var routeState: RouteState
    @Binding var isTracking: Bool
    var mapMode: MapMode = .turnByTurn
    var onMapTap: (() -> Void)?

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

        MapSynchronizers.updateCameras(
            uiView: uiView,
            coordinator: coordinator,
            cameras: bunnyPolice.cameras
        )

        MapSynchronizers.updateFriends(
            uiView: uiView,
            coordinator: coordinator,
            session: multiplayerService.activeSession
        )

        MapSynchronizers.updateSimulatedCar(
            uiView: uiView,
            coordinator: coordinator,
            routeState: routeState,
            location: locationProvider.currentLocation,
            vehicleMode: vehicleStore.selectedVehicle?.type ?? .car,
            isSimulating: locationProvider.isSimulating
        )

        MapSynchronizers.updateParkedCar(
            uiView: uiView,
            coordinator: coordinator,
            parkedCar: parkedCarStore.parkedCar
        )

        MapSynchronizers.updateDynamicCamera(
            uiView: uiView,
            coordinator: coordinator,
            routeState: routeState,
            mapMode: mapMode,
            location: locationProvider.currentLocation,
            isTracking: isTracking,
            speedMph: locationProvider.currentSpeedMPH,
            instructions: routingService.instructions,
            instructionIndex: routingService.currentInstructionIndex,
            activeRoute: routingService.activeRoute,
            distanceTraveled: locationProvider.isSimulating ? locationProvider.distanceTraveledInSimulationMeters : routingService.distanceTraveledMeters
        )

        MapSynchronizers.updateSearchLocationVehicle(
            uiView: uiView,
            coordinator: coordinator,
            routeState: routeState,
            location: locationProvider.currentLocation,
            vehicleMode: vehicleStore.selectedVehicle?.type ?? .car,
            character: playerStore.selectedCharacter
        )

        coordinator.lastRouteState = routeState

        MapSynchronizers.updateQuestWaypoints(
            uiView: uiView,
            coordinator: coordinator,
            activeQuest: routingService.questManager.activeQuest,
            currentLegIndex: routingService.questManager.currentLegIndex
        )

        MapSynchronizers.updateFreewayEntryIcons(
            uiView: uiView,
            coordinator: coordinator,
            instructions: routingService.instructions,
            activeRoute: routingService.activeRoute
        )

        MapSynchronizers.updateRouteOverlays(
            uiView: uiView,
            coordinator: coordinator,
            routeState: routeState,
            activeRoute: routingService.activeRoute,
            alternativeRoutes: routingService.activeAlternativeRoutes,
            selectedRouteIndex: routingService.selectedRouteIndex
        )
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

        func mapView(_ mapView: MKMapView, didUpdate userLocation: MKUserLocation) {
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

        func mapView(_ mapView: MKMapView, didChange mode: MKUserTrackingMode, animated: Bool) {
            DispatchQueue.main.async { self.parent.isTracking = (mode == .followWithHeading || mode == .follow) }
        }

        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            if parent.routeState == .search, let location = mapView.userLocation.location {
                let bearing = location.course >= 0 ? location.course : 0
                let screenBearing = bearing - mapView.camera.heading

                if let view = mapView.view(for: mapView.userLocation) {
                    let radians = CGFloat(screenBearing * .pi / 180.0)
                    view.transform = CGAffineTransform(rotationAngle: radians)
                }
            }
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
            let newAnns = await poiSearchService.searchPOIs(in: region)
            
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
}
