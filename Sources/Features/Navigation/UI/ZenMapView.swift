import SwiftUI
import MapKit

private let carChevronImage: UIImage = {
    let size = CGSize(width: 50, height: 60)
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { ctx in
        let context = ctx.cgContext
        context.setShadow(offset: CGSize(width: 0, height: 4), blur: 6,
                          color: UIColor.black.withAlphaComponent(0.3).cgColor)
        
        // Cute Camper Van Body
        let bodyPath = UIBezierPath(roundedRect: CGRect(x: 10, y: 15, width: 30, height: 40), cornerRadius: 10)
        UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0).setFill() // AC Mint Green
        bodyPath.fill()
        
        // Camper Top (White / Cream)
        let topPath = UIBezierPath(
            roundedRect: CGRect(x: 10, y: 10, width: 30, height: 20),
            byRoundingCorners: [.topLeft, .topRight],
            cornerRadii: CGSize(width: 10, height: 10)
        )
        UIColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1.0).setFill() // AC Cream
        topPath.fill()
        
        // Windshield
        let glassPath = UIBezierPath(roundedRect: CGRect(x: 14, y: 16, width: 22, height: 10), cornerRadius: 4)
        UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0).setFill() // AC Sky Blue
        glassPath.fill()
        
        // Surfboard / Camp Gear on roof
        let boardPath = UIBezierPath(roundedRect: CGRect(x: 22, y: 4, width: 6, height: 36), cornerRadius: 3)
        UIColor(red: 0.96, green: 0.77, blue: 0.19, alpha: 1.0).setFill() // AC Gold
        boardPath.fill()
        
        // White border around whole camper for map contrast
        let borderPath = UIBezierPath(roundedRect: CGRect(x: 10, y: 10, width: 30, height: 45), cornerRadius: 10)
        UIColor.white.setStroke()
        borderPath.lineWidth = 3.0
        borderPath.stroke()
        
        // Headlights
        let leftLight = UIBezierPath(ovalIn: CGRect(x: 14, y: 48, width: 6, height: 4))
        let rightLight = UIBezierPath(ovalIn: CGRect(x: 30, y: 48, width: 6, height: 4))
        UIColor(red: 1.0, green: 0.98, blue: 0.8, alpha: 1.0).setFill()
        leftLight.fill()
        rightLight.fill()
    }
}()

struct ZenMapView: UIViewRepresentable {
    @EnvironmentObject var locationProvider: LocationProvider
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var vehicleStore: VehicleStore
    @EnvironmentObject var multiplayerService: MultiplayerService
    @EnvironmentObject var playerStore: PlayerStore
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

    private func getVehicleImage(for type: VehicleType, character: Character) -> UIImage {
        let size = CGSize(width: 50, height: 60)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.setShadow(offset: CGSize(width: 0, height: 4), blur: 6,
                              color: UIColor.black.withAlphaComponent(0.3).cgColor)
            
            // Base properties
            var bodyColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
            var bodyRect = CGRect(x: 10, y: 15, width: 30, height: 40)
            var hasTop = true
            
            switch type {
            case .motorcycle, .scooter:
                bodyColor = UIColor.systemRed
                bodyRect = CGRect(x: 18, y: 10, width: 14, height: 40)
                hasTop = false
            case .bicycle:
                bodyColor = UIColor.systemBlue
                bodyRect = CGRect(x: 22, y: 15, width: 6, height: 35)
                hasTop = false
            case .truck:
                bodyColor = UIColor.systemGray
                bodyRect = CGRect(x: 5, y: 5, width: 40, height: 50)
            case .car:
                bodyColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
            }
            
            // Main Body
            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: type == .truck ? 4 : 10)
            bodyColor.setFill()
            bodyPath.fill()
            
            // Top/Roof (if applicable)
            if hasTop {
                let topPath = UIBezierPath(
                    roundedRect: CGRect(x: bodyRect.minX, y: bodyRect.minY - 5, width: bodyRect.width, height: bodyRect.height * 0.5),
                    byRoundingCorners: [.topLeft, .topRight],
                    cornerRadii: CGSize(width: type == .truck ? 4 : 10, height: type == .truck ? 4 : 10)
                )
                UIColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1.0).setFill()
                topPath.fill()
                
                // Windshield
                let glassPath = UIBezierPath(roundedRect: CGRect(x: bodyRect.minX + 4, y: bodyRect.minY + 1, width: bodyRect.width - 8, height: 10), cornerRadius: 4)
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0).setFill()
                glassPath.fill()
            } else if type == .motorcycle || type == .scooter {
                // Motorcycle Windshield
                let glassPath = UIBezierPath(roundedRect: CGRect(x: bodyRect.minX - 2, y: bodyRect.minY - 2, width: bodyRect.width + 4, height: 8), cornerRadius: 4)
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0).setFill()
                glassPath.fill()
                
                // Handlebars
                let barPath = UIBezierPath(rect: CGRect(x: bodyRect.minX - 6, y: bodyRect.minY + 6, width: bodyRect.width + 12, height: 3))
                UIColor.darkGray.setFill()
                barPath.fill()
            }
            
            // White border around whole camper for map contrast
            let borderPath = UIBezierPath(roundedRect: CGRect(x: bodyRect.minX, y: bodyRect.minY - (hasTop ? 5 : 0), width: bodyRect.width, height: bodyRect.height + (hasTop ? 5 : 0)), cornerRadius: type == .truck ? 4 : 10)
            UIColor.white.setStroke()
            borderPath.lineWidth = 3.0
            borderPath.stroke()
            
            // Headlights
            if type != .bicycle {
                let lightY = bodyRect.maxY - 2
                let leftLight = UIBezierPath(ovalIn: CGRect(x: bodyRect.minX + 4, y: lightY, width: 6, height: 4))
                let rightLight = UIBezierPath(ovalIn: CGRect(x: bodyRect.maxX - 10, y: lightY, width: 6, height: 4))
                UIColor(red: 1.0, green: 0.98, blue: 0.8, alpha: 1.0).setFill()
                leftLight.fill()
                rightLight.fill()
            }
            
            // Draw Character Emoji / Icon in the center (representing the driver)
            // Instead of just drawing a generic car, we overlay a cute circle for the animal!
            let avatarSize = CGSize(width: 28, height: 28)
            let avatarRect = CGRect(
                x: bodyRect.midX - (avatarSize.width / 2),
                y: bodyRect.midY - (avatarSize.height / 2) - (hasTop ? 4 : 8),
                width: avatarSize.width,
                height: avatarSize.height
            )
            
            // Circle Background matching character color
            if let uiColor = UIColor(hex: character.colorHex) {
                uiColor.setFill()
            } else {
                UIColor.systemOrange.setFill()
            }
            UIBezierPath(ovalIn: avatarRect).fill()
            
            // White border around avatar
            UIColor.white.setStroke()
            let avatarBorder = UIBezierPath(ovalIn: avatarRect)
            avatarBorder.lineWidth = 2
            avatarBorder.stroke()
            
            // Simple mapping from SF Symbol name to an Emoji (or just using a generic Animal emoji)
            var avatarEmoji = "🦊" // Default fox
            if character.icon.contains("bear") { avatarEmoji = "🐻" }
            else if character.icon.contains("bird") { avatarEmoji = "🐦" }
            else if character.icon.contains("hare") || character.icon.contains("rabbit") { avatarEmoji = "🐰" }
            else if character.icon.contains("cat") { avatarEmoji = "🐱" }
            else if character.icon.contains("dog") { avatarEmoji = "🐶" }
            
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 16)
            ]
            let strSize = avatarEmoji.size(withAttributes: attrs)
            avatarEmoji.draw(at: CGPoint(
                x: avatarRect.midX - (strSize.width / 2),
                y: avatarRect.midY - (strSize.height / 2)
            ), withAttributes: attrs)
        }
    }

    func updateUIView(_ uiView: MKMapView, context: Context) {
        let coordinator = context.coordinator

        let shouldShowNativeGPS = (routeState == .search)
        if uiView.showsUserLocation != shouldShowNativeGPS {
            uiView.showsUserLocation = shouldShowNativeGPS
        }

        // Add Cameras from BunnyPolice (only if not added yet)
        if coordinator.lastCameraCount != bunnyPolice.cameras.count {
            coordinator.lastCameraCount = bunnyPolice.cameras.count
            
            let oldCameras = uiView.annotations.compactMap { $0 as? CameraAnnotation }
            uiView.removeAnnotations(oldCameras)
            
            let newCameras = bunnyPolice.cameras.map { CameraAnnotation(camera: $0) }
            uiView.addAnnotations(newCameras)
        }

        // Handle Multiplayer Friends
        if let session = multiplayerService.activeSession {
            // Add/Update friends
            for member in session.members {
                if let existing = coordinator.friendAnnotations[member.id] {
                    // Animate the update
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
            
            // Remove missing friends
            let currentIDs = Set(session.members.map(\.id))
            let toRemove = coordinator.friendAnnotations.filter { !currentIDs.contains($0.key) }
            for (id, ann) in toRemove {
                uiView.removeAnnotation(ann)
                coordinator.friendAnnotations.removeValue(forKey: id)
            }
        } else if !coordinator.friendAnnotations.isEmpty {
            // Session ended, clean up
            uiView.removeAnnotations(Array(coordinator.friendAnnotations.values))
            coordinator.friendAnnotations.removeAll()
        }

        // Handle Car Annotation (Simulated OR Real Navigation)
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
                coordinator.simulatedCarAnnotation?.coordinate = location.coordinate
            }

            // Rotate car chevron — only when bearing changes by more than 2°
            let bearing = location.course >= 0 ? location.course : 0
            if abs(bearing - coordinator.lastBearing) > 2.0 {
                coordinator.lastBearing = bearing
                if let carAnnotation = coordinator.simulatedCarAnnotation,
                   let carView = uiView.view(for: carAnnotation) {
                    let radians = CGFloat(bearing * .pi / 180.0)
                    UIView.animate(withDuration: 0.1, delay: 0, options: [.curveLinear, .beginFromCurrentState]) {
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

        // Dynamic 3D camera during navigation
        if routeState == .navigating, let location = locationProvider.currentLocation, isTracking {
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
                let centerDistance = currentCenter.distance(to: lastCenter)
                
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
                    
                    uiView.setCamera(camera, animated: true)
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

        // Add Quest Waypoints (Cached to avoid O(N) annotations filtering per frame)
        let questCacheKey = routingService.activeQuest?.id.uuidString ?? "no_quest"
        if coordinator.lastQuestCacheKey != questCacheKey {
            coordinator.lastQuestCacheKey = questCacheKey
            
            // First clean up old quest annotations
            let toRemove = uiView.annotations.filter { $0 is QuestWaypointAnnotation }
            if !toRemove.isEmpty { uiView.removeAnnotations(toRemove) }
            
            // Then add new ones if a quest is active
            if let quest = routingService.activeQuest {
                let newWaypoints = quest.waypoints.map { QuestWaypointAnnotation(waypoint: $0) }
                uiView.addAnnotations(newWaypoints)
            }
        }

        // Add Freeway Entries
        let instructionCount = routingService.instructions.count
        if coordinator.lastInstructionCount != instructionCount && !routingService.activeRoute.isEmpty {
            coordinator.lastInstructionCount = instructionCount
            
            let oldFreewayAnnotations = uiView.annotations.compactMap { $0 as? POIAnnotation }.filter { $0.type == .freeway }
            uiView.removeAnnotations(oldFreewayAnnotations)
            
            var newFreewayAnnotations: [POIAnnotation] = []
            
            for inst in routingService.instructions {
                let msg = inst.text.lowercased()
                if msg.contains("motorway") || msg.contains("highway") || msg.contains("freeway") {
                    let idx = min(inst.pointIndex, routingService.activeRoute.count - 1)
                    if idx >= 0 && idx < routingService.activeRoute.count {
                        let coord = routingService.activeRoute[idx]
                        let ann = POIAnnotation(
                            coordinate: coord,
                            title: "Freeway Entry",
                            subtitle: inst.text,
                            type: .freeway
                        )
                        newFreewayAnnotations.append(ann)
                    }
                }
            }
            uiView.addAnnotations(newFreewayAnnotations)
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
        var lastQuestCacheKey: String = ""
        var lastBearing: Double = 0
        var lastRouteState: RouteState = .search
        var parkingAnnotationsLoaded = false
        var simulatedCarAnnotation: SimulatedCarAnnotation?
        var friendAnnotations: [String: FriendAnnotation] = [:]
        
        var lastCameraCenter: CLLocationCoordinate2D? = nil
        var lastCameraBearing: Double = 0
        var lastCameraDistance: Double = 0
        var lastCameraPitch: Double = 0
        var lastCameraCount: Int = -1
        var lastInstructionCount: Int = -1
        
        weak var mapView: MKMapView?

        var lastSearchRegion: MKCoordinateRegion?
        var isSearchingPOIs = false

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

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let currentRegion = mapView.region
            
            // Only search if region center moved significantly (> 500 meters) to avoid spamming
            if let last = lastSearchRegion {
                let currentLoc = CLLocation(latitude: currentRegion.center.latitude, longitude: currentRegion.center.longitude)
                let lastLoc = CLLocation(latitude: last.center.latitude, longitude: last.center.longitude)
                if currentLoc.distance(from: lastLoc) < 500 {
                    return
                }
            }
            
            guard !isSearchingPOIs else { return }
            isSearchingPOIs = true
            lastSearchRegion = currentRegion
            
            Task {
                await searchPOIs(in: currentRegion)
                DispatchQueue.main.async {
                    self.isSearchingPOIs = false
                }
            }
        }
        
        private func searchPOIs(in region: MKCoordinateRegion) async {
            let queries = [
                ("Police", POIAnnotation.POIType.emergency),
                ("Fire Station", POIAnnotation.POIType.emergency),
                ("Hospital", POIAnnotation.POIType.emergency),
                ("Post Office", POIAnnotation.POIType.emergency), // Treating as same tier for now
                ("School", POIAnnotation.POIType.school),
                ("Kindergarten", POIAnnotation.POIType.school),
                ("Daycare", POIAnnotation.POIType.school),
                ("College", POIAnnotation.POIType.school),
                ("Park", POIAnnotation.POIType.park)
            ]
            
            var newAnnotations: [POIAnnotation] = []
            
            for (query, type) in queries {
                let request = MKLocalSearch.Request()
                request.naturalLanguageQuery = query
                request.region = region
                
                do {
                    let search = MKLocalSearch(request: request)
                    let response = try await search.start()
                    
                    for item in response.mapItems {
                        let ann = POIAnnotation(
                            coordinate: item.placemark.coordinate,
                            title: item.name,
                            subtitle: query,
                            type: type,
                            mapItem: item
                        )
                        newAnnotations.append(ann)
                    }
                } catch {
                    // Ignore errors, just skip
                }
            }
            
            await MainActor.run {
                guard let mapView = self.mapView else { return }
                // Remove old POIs to prevent clutter
                let oldAnnotations = mapView.annotations.compactMap { $0 as? POIAnnotation }
                mapView.removeAnnotations(oldAnnotations)
                mapView.addAnnotations(newAnnotations)
            }
        }

        func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
            if let poiAnnotation = view.annotation as? POIAnnotation {
                NotificationCenter.default.post(
                    name: NSNotification.Name("AddPOIToRoute"),
                    object: poiAnnotation
                )
            }
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }

            if let carAnn = annotation as? SimulatedCarAnnotation {
                let identifier = "Car_\(carAnn.vehicleType.rawValue)"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.layer.shadowColor = UIColor.black.cgColor
                    view?.layer.shadowOpacity = 0.3
                    view?.layer.shadowRadius = 4
                }
                view?.image = parent.getVehicleImage(for: carAnn.vehicleType, character: parent.playerStore.selectedCharacter)
                return view
            }
            
            if let friendAnn = annotation as? FriendAnnotation {
                let identifier = "Friend"
                var view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier)
                if view == nil {
                    view = MKAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                    view?.layer.shadowColor = UIColor.black.cgColor
                    view?.layer.shadowOpacity = 0.5
                    view?.layer.shadowRadius = 4
                }
                
                // Draw a simple friend marker (a circle with an emoji)
                let size = CGSize(width: 40, height: 40)
                let renderer = UIGraphicsImageRenderer(size: size)
                view?.image = renderer.image { ctx in
                    UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0).setFill()
                    UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
                    UIColor.white.setStroke()
                    let path = UIBezierPath(ovalIn: CGRect(x: 2, y: 2, width: 36, height: 36))
                    path.lineWidth = 2
                    path.stroke()
                    
                    let attrs: [NSAttributedString.Key: Any] = [
                        .font: UIFont.systemFont(ofSize: 20)
                    ]
                    let str = friendAnn.memberAvatar ?? "🐶"
                    let strSize = str.size(withAttributes: attrs)
                    str.draw(at: CGPoint(x: (size.width - strSize.width) / 2, y: (size.height - strSize.height) / 2), withAttributes: attrs)
                }
                
                view?.transform = CGAffineTransform(rotationAngle: CGFloat(friendAnn.memberHeading * .pi / 180.0))
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

            if let poiAnnotation = annotation as? POIAnnotation {
                let identifier = "POI_\(poiAnnotation.type)"
                var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                if annotationView == nil {
                    annotationView = MKMarkerAnnotationView(annotation: poiAnnotation, reuseIdentifier: identifier)
                    annotationView?.canShowCallout = true
                    
                    let addButton = UIButton(type: .contactAdd)
                    addButton.tintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                    annotationView?.rightCalloutAccessoryView = addButton
                } else {
                    annotationView?.annotation = poiAnnotation
                }
                
                switch poiAnnotation.type {
                case .emergency:
                    if poiAnnotation.title?.lowercased().contains("fire") == true {
                        annotationView?.glyphImage = UIImage(systemName: "flame.fill")
                        annotationView?.markerTintColor = .systemRed
                    } else if poiAnnotation.title?.lowercased().contains("police") == true {
                        annotationView?.glyphImage = UIImage(systemName: "shield.fill")
                        annotationView?.markerTintColor = .systemBlue
                    } else {
                        annotationView?.glyphImage = UIImage(systemName: "cross.case.fill")
                        annotationView?.markerTintColor = .white
                        annotationView?.glyphTintColor = .systemRed
                    }
                case .school:
                    annotationView?.glyphImage = UIImage(systemName: "figure.child")
                    annotationView?.markerTintColor = .systemYellow
                case .park:
                    annotationView?.glyphImage = UIImage(systemName: "tree.fill")
                    annotationView?.markerTintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                case .freeway:
                    annotationView?.glyphImage = UIImage(systemName: "car.fill")
                    annotationView?.markerTintColor = .systemBlue
                }
                
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
    var vehicleType: VehicleType

    init(coordinate: CLLocationCoordinate2D, vehicleType: VehicleType) {
        self.coordinate = coordinate
        self.vehicleType = vehicleType
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

class FriendAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var memberId: String
    var memberName: String
    var memberAvatar: String?
    var memberHeading: Double

    init(memberId: String, memberName: String, memberAvatar: String?, coordinate: CLLocationCoordinate2D, heading: Double) {
        self.memberId = memberId
        self.memberName = memberName
        self.memberAvatar = memberAvatar
        self.coordinate = coordinate
        self.memberHeading = heading
        super.init()
    }
}

class POIAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let type: POIType
    let mapItem: MKMapItem?
    
    enum POIType {
        case emergency, school, park, freeway
    }
    
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, type: POIType, mapItem: MKMapItem? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.mapItem = mapItem
        super.init()
    }
}
