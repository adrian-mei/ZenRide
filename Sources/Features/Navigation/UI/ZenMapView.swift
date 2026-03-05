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
        mapView.delegate = context.coordinator as! ZenMapCoordinator
        (context.coordinator as! ZenMapCoordinator).mapView = mapView

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
        let tapGesture = UITapGestureRecognizer(target: context.coordinator as ZenMapCoordinator, action: #selector(Coordinator.handleTap(_:)))
        mapView.addGestureRecognizer(tapGesture)

        return mapView
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let coordinator = context.coordinator as! ZenMapCoordinator

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

        MapCameraEngine.updateDynamicCamera(
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

    func makeZenMapCoordinator() -> Coordinator { ZenMapCoordinator(self) }

    // MARK: - Coordinator

    func makeCoordinator() -> ZenMapCoordinator { ZenMapCoordinator(self) }
}