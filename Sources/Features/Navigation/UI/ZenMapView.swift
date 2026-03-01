import SwiftUI
import MapKit
import UIKit

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
        if type.isOnFoot {
            return makeOnFootImage(for: character)
        }
        return makeVehicleImage(for: type, character: character)
    }

    private func makeOnFootImage(for character: Character) -> UIImage {
        let size = CGSize(width: 44, height: 44)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.setShadow(offset: CGSize(width: 0, height: 3), blur: 6,
                              color: UIColor.black.withAlphaComponent(0.35).cgColor)

            let avatarRect = CGRect(x: 2, y: 2, width: 40, height: 40)
            let charColor = UIColor(hex: character.colorHex) ?? .systemOrange
            charColor.setFill()
            UIBezierPath(ovalIn: avatarRect).fill()

            UIColor.white.setStroke()
            let border = UIBezierPath(ovalIn: avatarRect)
            border.lineWidth = 3
            border.stroke()

            drawCharacterSymbol(character: character, in: avatarRect, padding: 8)
        }
    }

    private func makeVehicleImage(for type: VehicleType, character: Character) -> UIImage {
        let size = CGSize(width: 50, height: 60)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            let context = ctx.cgContext
            context.setShadow(offset: CGSize(width: 0, height: 4), blur: 6,
                              color: UIColor.black.withAlphaComponent(0.3).cgColor)

            var bodyColor: UIColor
            var bodyRect: CGRect
            var hasTop: Bool
            var cornerRadius: CGFloat = 10

            switch type {
            case .car:
                bodyColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                bodyRect  = CGRect(x: 10, y: 15, width: 30, height: 40)
                hasTop    = true
            case .sportsCar:
                bodyColor = UIColor.systemRed
                bodyRect  = CGRect(x: 8, y: 22, width: 34, height: 32)
                hasTop    = true
            case .electricCar:
                bodyColor = UIColor.systemCyan
                bodyRect  = CGRect(x: 10, y: 15, width: 30, height: 40)
                hasTop    = true
            case .suv:
                bodyColor    = UIColor(red: 0.4, green: 0.55, blue: 0.35, alpha: 1.0)
                bodyRect     = CGRect(x: 6, y: 8, width: 38, height: 46)
                hasTop       = true
                cornerRadius = 6
            case .truck:
                bodyColor    = UIColor.systemGray
                bodyRect     = CGRect(x: 5, y: 5, width: 40, height: 50)
                hasTop       = true
                cornerRadius = 4
            case .motorcycle, .scooter:
                bodyColor = UIColor.systemRed
                bodyRect  = CGRect(x: 18, y: 10, width: 14, height: 40)
                hasTop    = false
            case .bicycle:
                bodyColor = UIColor.systemBlue
                bodyRect  = CGRect(x: 22, y: 15, width: 6, height: 35)
                hasTop    = false
            case .mountainBike:
                bodyColor = UIColor.systemGreen
                bodyRect  = CGRect(x: 22, y: 15, width: 6, height: 35)
                hasTop    = false
            case .walking, .running, .skateboard:
                bodyColor = UIColor.clear
                bodyRect  = CGRect(x: 11, y: 10, width: 28, height: 40)
                hasTop    = false
            }

            let bodyPath = UIBezierPath(roundedRect: bodyRect, cornerRadius: cornerRadius)
            bodyColor.setFill()
            bodyPath.fill()

            if hasTop {
                let roofRect = CGRect(x: bodyRect.minX, y: bodyRect.minY - 5,
                                      width: bodyRect.width, height: bodyRect.height * 0.5)
                let roofPath = UIBezierPath(roundedRect: roofRect,
                                             byRoundingCorners: [.topLeft, .topRight],
                                             cornerRadii: CGSize(width: cornerRadius, height: cornerRadius))
                UIColor(red: 1.0, green: 0.98, blue: 0.90, alpha: 1.0).setFill()
                roofPath.fill()

                let glassPath = UIBezierPath(roundedRect: CGRect(x: bodyRect.minX + 4, y: bodyRect.minY + 1,
                                                                   width: bodyRect.width - 8, height: 10),
                                             cornerRadius: 4)
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0).setFill()
                glassPath.fill()

                if type == .sportsCar {
                    let spoilerPath = UIBezierPath(rect: CGRect(x: bodyRect.minX - 2, y: bodyRect.minY - 4,
                                                                 width: bodyRect.width + 4, height: 3))
                    UIColor.darkGray.setFill()
                    spoilerPath.fill()
                }
            } else if type == .motorcycle || type == .scooter {
                let screenPath = UIBezierPath(roundedRect: CGRect(x: bodyRect.minX - 2, y: bodyRect.minY - 2,
                                                                    width: bodyRect.width + 4, height: 8),
                                              cornerRadius: 4)
                UIColor(red: 0.53, green: 0.81, blue: 0.92, alpha: 1.0).setFill()
                screenPath.fill()

                let barPath = UIBezierPath(rect: CGRect(x: bodyRect.minX - 6, y: bodyRect.minY + 6,
                                                         width: bodyRect.width + 12, height: 3))
                UIColor.darkGray.setFill()
                barPath.fill()
            } else if type == .bicycle || type == .mountainBike {
                let wheelColor = (type == .mountainBike) ? UIColor.systemGreen : UIColor.systemBlue
                for wheelY in [bodyRect.minY + 3, bodyRect.maxY - 9] {
                    let wheelPath = UIBezierPath(ovalIn: CGRect(x: bodyRect.minX - 7, y: wheelY, width: 20, height: 20))
                    wheelColor.withAlphaComponent(0.4).setFill()
                    wheelPath.fill()
                    wheelColor.setStroke()
                    wheelPath.lineWidth = 2
                    wheelPath.stroke()
                }
            }

            let borderRect = CGRect(x: bodyRect.minX, y: bodyRect.minY - (hasTop ? 5 : 0),
                                    width: bodyRect.width, height: bodyRect.height + (hasTop ? 5 : 0))
            let borderPath = UIBezierPath(roundedRect: borderRect, cornerRadius: cornerRadius)
            UIColor.white.setStroke()
            borderPath.lineWidth = 3
            borderPath.stroke()

            if !type.isOnFoot && type != .bicycle && type != .mountainBike {
                let lightY = bodyRect.maxY - 2
                for xOff in [bodyRect.minX + 4, bodyRect.maxX - 10] {
                    let lightPath = UIBezierPath(ovalIn: CGRect(x: xOff, y: lightY, width: 6, height: 4))
                    UIColor(red: 1.0, green: 0.98, blue: 0.8, alpha: 1.0).setFill()
                    lightPath.fill()
                }
            }

            let avatarDiam: CGFloat = 28
            let avatarRect = CGRect(
                x: bodyRect.midX - avatarDiam / 2,
                y: bodyRect.midY - avatarDiam / 2 - (hasTop ? 4 : 8),
                width: avatarDiam, height: avatarDiam
            )
            let charColor = UIColor(hex: character.colorHex) ?? .systemOrange
            charColor.setFill()
            UIBezierPath(ovalIn: avatarRect).fill()

            let avatarBorder = UIBezierPath(ovalIn: avatarRect)
            UIColor.white.setStroke()
            avatarBorder.lineWidth = 2
            avatarBorder.stroke()

            drawCharacterSymbol(character: character, in: avatarRect, padding: 5)
        }
    }

    private func drawCharacterSymbol(character: Character, in rect: CGRect, padding: CGFloat) {
        let config = UIImage.SymbolConfiguration(pointSize: rect.width - padding * 2, weight: .bold)
        if let symbol = UIImage(systemName: character.icon, withConfiguration: config)?
                .withTintColor(.white, renderingMode: .alwaysOriginal) {
            let symSize = symbol.size
            let origin = CGPoint(
                x: rect.midX - symSize.width / 2,
                y: rect.midY - symSize.height / 2
            )
            symbol.draw(at: origin)
        }
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
                    let distToTurnFt = distToTurn * 3.28084
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

        // Waypoints
        let questCacheKey = "\(routingService.activeQuest?.id.uuidString ?? "no_quest")_\(routingService.currentLegIndex)"
        if coordinator.lastQuestCacheKey != questCacheKey {
            coordinator.lastQuestCacheKey = questCacheKey
            uiView.removeAnnotations(uiView.annotations.filter { $0 is QuestWaypointAnnotation })
            if let quest = routingService.activeQuest {
                var anns: [QuestWaypointAnnotation] = []
                for i in 0..<quest.waypoints.count {
                    anns.append(QuestWaypointAnnotation(waypoint: quest.waypoints[i], index: i))
                }
                uiView.addAnnotations(anns)
            }
        }

        // Freeway Entry Icons
        let instructionCount = routingService.instructions.count
        if coordinator.lastInstructionCount != instructionCount && !routingService.activeRoute.isEmpty {
            coordinator.lastInstructionCount = instructionCount
            uiView.removeAnnotations(uiView.annotations.compactMap { $0 as? POIAnnotation }.filter { $0.type == .freeway })
            var freewayAnns: [POIAnnotation] = []
            for inst in routingService.instructions {
                let msg = inst.text.lowercased()
                if msg.contains("motorway") || msg.contains("highway") || msg.contains("freeway") {
                    let idx = min(inst.pointIndex, routingService.activeRoute.count - 1)
                    if idx >= 0 {
                        freewayAnns.append(POIAnnotation(coordinate: routingService.activeRoute[idx], title: "Freeway Entry", subtitle: inst.text, type: .freeway))
                    }
                }
            }
            uiView.addAnnotations(freewayAnns)
        }

        // Overlays
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
                if CLLocation(latitude: current.center.latitude, longitude: current.center.longitude).distance(from: CLLocation(latitude: last.center.latitude, longitude: last.center.longitude)) < 500 { return }
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
            let queries: [(String, POIAnnotation.POIType)] = [("Police", .emergency), ("Fire Station", .emergency), ("Hospital", .emergency), ("School", .school), ("Park", .park)]
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
            if let poi = view.annotation as? POIAnnotation { NotificationCenter.default.post(name: AppNotification.addPOIToRoute, object: poi) }
        }
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation { return nil }
            if let car = annotation as? SimulatedCarAnnotation {
                let id = "Car_\(car.vehicleType.rawValue)"
                var v = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                if v == nil { v = MKAnnotationView(annotation: annotation, reuseIdentifier: id); v?.layer.shadowColor = UIColor.black.cgColor; v?.layer.shadowOpacity = 0.3; v?.layer.shadowRadius = 4 }
                v?.image = parent.getVehicleImage(for: car.vehicleType, character: parent.playerStore.selectedCharacter)
                return v
            }
            if let friend = annotation as? FriendAnnotation {
                let id = "Friend"
                var v = mapView.dequeueReusableAnnotationView(withIdentifier: id)
                if v == nil { v = MKAnnotationView(annotation: annotation, reuseIdentifier: id); v?.layer.shadowColor = UIColor.black.cgColor; v?.layer.shadowOpacity = 0.5; v?.layer.shadowRadius = 4 }
                let size = CGSize(width: 40, height: 40)
                v?.image = UIGraphicsImageRenderer(size: size).image { _ in
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
                v?.transform = CGAffineTransform(rotationAngle: CGFloat(friend.memberHeading * .pi / 180.0))
                return v
            }
            if let wp = annotation as? QuestWaypointAnnotation {
                let id = "QuestWP"
                var v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                if v == nil { v = MKMarkerAnnotationView(annotation: wp, reuseIdentifier: id); v?.canShowCallout = true }
                else { v?.annotation = wp }
                
                let isPast = wp.index <= parent.routingService.currentLegIndex
                let isTarget = wp.index == parent.routingService.currentLegIndex + 1
                
                v?.glyphImage = UIImage(systemName: isPast ? "checkmark" : wp.wp.icon)
                v?.glyphTintColor = .white
                
                if isPast {
                    v?.markerTintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0) // Leaf
                    v?.displayPriority = .defaultLow
                } else if isTarget {
                    v?.markerTintColor = .systemOrange
                    v?.displayPriority = .required
                } else {
                    v?.markerTintColor = UIColor(red: 0.83, green: 0.71, blue: 0.51, alpha: 1.0) // Wood
                    v?.displayPriority = .defaultHigh
                }
                return v
            }
            if let cam = annotation as? CameraAnnotation {
                let id = "Camera"
                var v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                if v == nil { v = MKMarkerAnnotationView(annotation: cam, reuseIdentifier: id) }
                v?.glyphImage = UIImage(systemName: "camera.fill"); v?.markerTintColor = .systemOrange
                return v
            }
            if let poi = annotation as? POIAnnotation {
                let id = "POI_\(poi.type)"
                var v = mapView.dequeueReusableAnnotationView(withIdentifier: id) as? MKMarkerAnnotationView
                if v == nil { v = MKMarkerAnnotationView(annotation: poi, reuseIdentifier: id); v?.canShowCallout = true; let btn = UIButton(type: .contactAdd); btn.tintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0); v?.rightCalloutAccessoryView = btn }
                switch poi.type {
                case .emergency: v?.glyphImage = UIImage(systemName: "shield.fill"); v?.markerTintColor = .systemBlue
                case .school: v?.glyphImage = UIImage(systemName: "figure.child"); v?.markerTintColor = .systemYellow
                case .park: v?.glyphImage = UIImage(systemName: "tree.fill"); v?.markerTintColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0)
                case .freeway: v?.glyphImage = UIImage(systemName: "car.fill"); v?.markerTintColor = .systemBlue
                }
                return v
            }
            return nil
        }
        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let poly = overlay as? BorderedPolyline {
                let r = MKPolylineRenderer(polyline: poly)
                if poly.subtitle == "selected" {
                    if poly.isBorder { r.strokeColor = UIColor(red: 0.83, green: 0.71, blue: 0.51, alpha: 1.0); r.lineWidth = 14 }
                    else { r.strokeColor = UIColor(red: 0.35, green: 0.68, blue: 0.43, alpha: 1.0); r.lineWidth = 8; r.lineDashPattern = [12, 8] }
                } else { r.strokeColor = UIColor.systemGray3.withAlphaComponent(0.6); r.lineWidth = 8 }
                r.lineCap = .round; r.lineJoin = .round; return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
class BorderedPolyline: MKPolyline { var isBorder = false }
class SimulatedCarAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var vehicleType: VehicleType
    init(coordinate: CLLocationCoordinate2D, vehicleType: VehicleType) { self.coordinate = coordinate; self.vehicleType = vehicleType; super.init() }
}
class QuestWaypointAnnotation: NSObject, MKAnnotation {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let wp: QuestWaypoint
    let index: Int

    init(waypoint: QuestWaypoint, index: Int) {
        self.id = waypoint.id
        self.wp = waypoint
        self.index = index
        self.coordinate = waypoint.coordinate
        self.title = waypoint.name
        super.init()
    }
}
class CameraAnnotation: NSObject, MKAnnotation {
    let id: String; let coordinate: CLLocationCoordinate2D; let title: String?; let subtitle: String?
    init(camera: SpeedCamera) { self.id = camera.id; self.coordinate = CLLocationCoordinate2D(latitude: camera.lat, longitude: camera.lng); self.title = "Speed Camera"; self.subtitle = "Speed Limit: \(camera.speed_limit_mph) MPH"; super.init() }
}
class FriendAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D; var memberId: String; var memberName: String; var memberAvatar: String?; var memberHeading: Double
    init(memberId: String, memberName: String, memberAvatar: String?, coordinate: CLLocationCoordinate2D, heading: Double) { self.memberId = memberId; self.memberName = memberName; self.memberAvatar = memberAvatar; self.coordinate = coordinate; self.memberHeading = heading; super.init() }
}
class POIAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D; let title: String?; let subtitle: String?; let type: POIType; let mapItem: MKMapItem?
    enum POIType { case emergency, school, park, freeway }
    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?, type: POIType, mapItem: MKMapItem? = nil) { self.coordinate = coordinate; self.title = title; self.subtitle = subtitle; self.type = type; self.mapItem = mapItem; super.init() }
}
