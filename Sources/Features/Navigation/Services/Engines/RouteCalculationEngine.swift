import Foundation
import CoreLocation

enum RouteCalculationResult {
    case success(routes: [TomTomRoute], activeAlternativeRoutes: [[CLLocationCoordinate2D]], selectedIndex: Int)
    case mock(routes: [TomTomRoute], activeAlternativeRoutes: [[CLLocationCoordinate2D]], selectedIndex: Int)
    case failure(Error)
}

struct RouteCalculationEngine {
    let apiClient: TomTomRoutingClient
    let useMockData: Bool

    init(apiClient: TomTomRoutingClient, useMockData: Bool = false) {
        self.apiClient = apiClient
        self.useMockData = useMockData
    }

    func calculateSafeRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D,
        avoiding cameras: [SpeedCamera],
        avoidTolls: Bool,
        avoidHighways: Bool,
        avoidSpeedCameras: Bool,
        vehicleMode: VehicleMode
    ) async -> RouteCalculationResult {
        
        if useMockData {
            do {
                let data = MockRoutingData.tomTomResponseJSON.data(using: .utf8)!
                let result = try JSONDecoder().decode(TomTomRouteResponse.self, from: data)
                let activeAlternativeRoutes = result.routes.compactMap { route in
                    route.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                }
                let defaultIndex = avoidSpeedCameras
                    ? (result.routes.firstIndex(where: { $0.isZeroCameras }) ?? 0)
                    : 0
                return .mock(routes: result.routes, activeAlternativeRoutes: activeAlternativeRoutes, selectedIndex: defaultIndex)
            } catch {
                return .failure(error)
            }
        }

        var avoidFeatures: [String] = []
        if avoidTolls { avoidFeatures.append("tollRoads") }
        if avoidHighways { avoidFeatures.append("motorways") }

        let cameraAvoidAreas = cameras.map { $0.boundingBoxForRouting }.joined(separator: "!")

        do {
            var standardRoutes: [TomTomRoute] = []
            if let stdData = try await apiClient.fetchRoute(
                origin: origin,
                destination: destination,
                avoidAreas: "",
                avoidFeatures: avoidFeatures,
                travelMode: vehicleMode.tomTomTravelMode
            ) {
                var mapped = stdData.routes
                for i in 0..<mapped.count {
                    let count = countCameras(on: mapped[i], cameras: cameras)
                    mapped[i].cameraCount = count
                    mapped[i].isSafeRoute = (count == 0)
                }
                standardRoutes = mapped
            }

            var safeRoutes: [TomTomRoute] = []
            if avoidSpeedCameras {
                if let safeData = try await apiClient.fetchRoute(
                    origin: origin,
                    destination: destination,
                    avoidAreas: cameraAvoidAreas,
                    avoidFeatures: avoidFeatures,
                    travelMode: vehicleMode.tomTomTravelMode
                ) {
                    var mapped = safeData.routes
                    for i in 0..<mapped.count {
                        mapped[i].cameraCount = 0
                        mapped[i].isSafeRoute = true
                    }
                    safeRoutes = mapped
                }
            }

            var combined = standardRoutes
            for safe in safeRoutes {
                let isDuplicate = combined.contains {
                    abs($0.summary.travelTimeInSeconds - safe.summary.travelTimeInSeconds) < 10
                    && abs($0.summary.lengthInMeters - safe.summary.lengthInMeters) < 100
                }
                if !isDuplicate { combined.append(safe) }
            }

            let activeAlternativeRoutes = combined.compactMap { route in
                route.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            }
            let defaultIndex = avoidSpeedCameras
                ? (combined.firstIndex(where: { $0.isSafeRoute }) ?? 0)
                : 0

            return .success(routes: combined, activeAlternativeRoutes: activeAlternativeRoutes, selectedIndex: defaultIndex)
        } catch {
            return .failure(error)
        }
    }

    func countCameras(on route: TomTomRoute, cameras: [SpeedCamera]) -> Int {
        var count = 0
        guard let leg = route.legs.first else { return 0 }

        let legPoints = leg.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard let first = legPoints.first else { return 0 }

        var minLat = first.latitude
        var maxLat = first.latitude
        var minLng = first.longitude
        var maxLng = first.longitude

        for p in legPoints {
            if p.latitude < minLat { minLat = p.latitude }
            if p.latitude > maxLat { maxLat = p.latitude }
            if p.longitude < minLng { minLng = p.longitude }
            if p.longitude > maxLng { maxLng = p.longitude }
        }

        minLat -= 0.001
        maxLat += 0.001
        minLng -= 0.001
        maxLng += 0.001

        for camera in cameras {
            if camera.lat < minLat || camera.lat > maxLat || camera.lng < minLng || camera.lng > maxLng {
                continue
            }

            let camLoc = CLLocationCoordinate2D(latitude: camera.lat, longitude: camera.lng)
            for pLoc in legPoints {
                if pLoc.distance(to: camLoc) < 70 {
                    count += 1
                    break
                }
            }
        }
        return count
    }
}