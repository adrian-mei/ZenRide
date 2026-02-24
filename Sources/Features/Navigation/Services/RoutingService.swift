import Foundation
import CoreLocation

enum VehicleMode: String, CaseIterable {
    case motorcycle
    case car

    var icon: String {
        switch self {
        case .motorcycle: return "motorcycle"
        case .car:        return "car.fill"
        }
    }

    var displayName: String {
        switch self {
        case .motorcycle: return "Motorcycle"
        case .car:        return "Car"
        }
    }

    /// Camera avoidance default for this mode
    var defaultAvoidCameras: Bool { self == .motorcycle }
}

enum RoutingError: Error {
    case invalidURL
    case noData
    case parsingError
    case apiError(String)
}

struct TomTomRouteResponse: Decodable {
    let routes: [TomTomRoute]
}

struct TomTomSummary: Decodable {
    let lengthInMeters: Int
    let travelTimeInSeconds: Int
}

struct TomTomGuidance: Decodable {
    let instructions: [TomTomInstruction]?
}

enum RoadFeature {
    case stopSign
    case trafficLight
    case freewayEntry
    case freewayExit
    case roundabout
    case none
}

struct TomTomInstruction: Decodable {
    let routeOffsetInMeters: Int
    let travelTimeInSeconds: Int
    let pointIndex: Int
    let instructionType: String?
    let street: String?
    let message: String?

    var roadFeature: RoadFeature {
        let msg = message?.lowercased() ?? ""
        if instructionType == "MOTORWAY_ENTER" { return .freewayEntry }
        if instructionType == "MOTORWAY_EXIT"  { return .freewayExit }
        if instructionType?.hasPrefix("ROUNDABOUT") == true { return .roundabout }
        if msg.contains("traffic signal") || msg.contains("traffic light") { return .trafficLight }
        if msg.contains("stop sign") { return .stopSign }
        return .none
    }
}

struct TomTomRoute: Decodable, Identifiable {
    var id = UUID()
    let summary: TomTomSummary
    let tags: [String]?
    let legs: [TomTomLeg]
    let guidance: TomTomGuidance?

    var cameraCount: Int = 0
    var isSafeRoute: Bool = false
    var savedFines: Int { cameraCount * 100 }

    enum CodingKeys: String, CodingKey {
        case summary, tags, legs, guidance
    }

    var isZeroCameras: Bool {
        tags?.contains("zero_cameras") == true || isSafeRoute || cameraCount == 0
    }

    var isLessTraffic: Bool {
        tags?.contains("less_traffic") == true
    }
}

struct TomTomLeg: Decodable {
    let points: [TomTomPoint]
}

struct TomTomPoint: Decodable {
    let latitude: Double
    let longitude: Double
}

class RoutingService: ObservableObject {
    @Published var availableRoutes: [TomTomRoute] = []
    @Published var selectedRouteIndex: Int = 0

    @Published var activeRoute: [CLLocationCoordinate2D] = []
    @Published var activeAlternativeRoutes: [[CLLocationCoordinate2D]] = []

    @Published var routeProgressIndex: Int = 0

    @Published var routeDistanceMeters: Int = 0
    @Published var routeTimeSeconds: Int = 0
    @Published var instructions: [TomTomInstruction] = []
    @Published var currentInstructionIndex: Int = 0 {
        didSet {
            hasWarned500ft = false
            hasWarned100ft = false
        }
    }
    @Published var isCalculatingRoute = false

    // MARK: - Vehicle Mode

    @Published var vehicleMode: VehicleMode = .motorcycle {
        didSet {
            guard vehicleMode != oldValue else { return }
            // Apply mode defaults without overriding explicit user toggles
            avoidSpeedCameras = vehicleMode.defaultAvoidCameras
            Task { await recalculate() }
        }
    }

    // MARK: - Route Preferences

    @Published var avoidTolls: Bool = false
    @Published var avoidHighways: Bool = false
    @Published var avoidSpeedCameras: Bool = true

    // Stored for preference-driven recalculation
    private var lastOrigin: CLLocationCoordinate2D?
    private var lastDestination: CLLocationCoordinate2D?
    private var lastCameras: [SpeedCamera]?

    // Cumulative distance (meters) to each route point — index matches activeRoute
    private(set) var coordinateDistances: [Double] = []

    /// Distance traveled along the route based on the current progress segment.
    /// Used by guidance views during real GPS navigation (non-simulation).
    var distanceTraveledMeters: Double {
        guard !coordinateDistances.isEmpty else { return 0 }
        return coordinateDistances[min(routeProgressIndex, coordinateDistances.count - 1)]
    }

    // Haptic state tracking
    var hasWarned500ft = false
    var hasWarned100ft = false

    private let apiKey = Secrets.tomTomAPIKey
    var useMockData = false

    // MARK: - Recalculate with stored params (called on preference change)

    func recalculate() async {
        guard let origin = lastOrigin,
              let destination = lastDestination,
              let cameras = lastCameras else { return }
        await calculateSafeRoute(from: origin, to: destination, avoiding: cameras)
    }

    // MARK: - Rerouting

    func checkReroute(currentLocation: CLLocation) {
        guard activeRoute.count > 1 else { return }

        let currentCoord = currentLocation.coordinate
        var minDistance = Double.greatestFiniteMagnitude
        var closestSegmentIndex = routeProgressIndex

        let searchEndIndex = min(routeProgressIndex + 50, activeRoute.count - 1)

        if routeProgressIndex < activeRoute.count - 1 {
            for i in routeProgressIndex..<searchEndIndex {
                let start = activeRoute[i]
                let end = activeRoute[i + 1]
                let distance = currentCoord.distanceToSegment(start: start, end: end)
                if distance < minDistance {
                    minDistance = distance
                    closestSegmentIndex = i
                }
            }

            DispatchQueue.main.async {
                // Re-check bounds: activeRoute may have changed before this block executes
                if closestSegmentIndex > self.routeProgressIndex,
                   closestSegmentIndex < self.activeRoute.count {
                    self.routeProgressIndex = closestSegmentIndex
                }
            }
        } else {
            guard let lastPoint = activeRoute.last else { return }
            minDistance = currentCoord.distance(to: lastPoint)
        }

        if minDistance > 100 {
            Log.info("Routing", "Off route — switching to next alternative")
            DispatchQueue.main.async {
                if self.availableRoutes.count > 1 {
                    let newIndex = (self.selectedRouteIndex + 1) % self.availableRoutes.count
                    self.selectRoute(at: newIndex)
                }
            }
        }
    }

    // MARK: - Route Selection

    func selectRoute(at index: Int) {
        guard index >= 0 && index < availableRoutes.count else { return }
        selectedRouteIndex = index
        let route = availableRoutes[index]

        var totalCalculatedDistance = 0.0
        coordinateDistances = [0.0]

        if let firstLeg = route.legs.first {
            let coordinates = firstLeg.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            activeRoute = coordinates

            for i in 1..<coordinates.count {
                let dist = coordinates[i-1].distance(to: coordinates[i])
                totalCalculatedDistance += dist
                coordinateDistances.append(totalCalculatedDistance)
            }
        }

        if useMockData {
            routeDistanceMeters = Int(totalCalculatedDistance)
            routeTimeSeconds = Int(totalCalculatedDistance / 15.0)

            if let oldInstructions = route.guidance?.instructions {
                instructions = oldInstructions.map { inst in
                    let trueOffset = inst.pointIndex < coordinateDistances.count ? Int(coordinateDistances[inst.pointIndex]) : Int(totalCalculatedDistance)
                    return TomTomInstruction(
                        routeOffsetInMeters: trueOffset,
                        travelTimeInSeconds: Int(Double(trueOffset) / 15.0),
                        pointIndex: inst.pointIndex,
                        instructionType: inst.instructionType,
                        street: inst.street,
                        message: inst.message
                    )
                }
            } else {
                instructions = []
            }
        } else {
            routeDistanceMeters = route.summary.lengthInMeters
            routeTimeSeconds = route.summary.travelTimeInSeconds
            instructions = route.guidance?.instructions ?? []
        }
        currentInstructionIndex = 0
        routeProgressIndex = 0
    }

    // MARK: - Camera Counting

    private func countCameras(on route: TomTomRoute, cameras: [SpeedCamera]) -> Int {
        var count = 0
        guard let leg = route.legs.first else { return 0 }

        for camera in cameras {
            let camLoc = CLLocationCoordinate2D(latitude: camera.lat, longitude: camera.lng)
            for point in leg.points {
                let pLoc = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                if pLoc.distance(to: camLoc) < 70 {
                    count += 1
                    break
                }
            }
        }
        return count
    }

    // MARK: - TomTom Fetch

    private func fetchTomTom(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        avoidAreas: String,
        avoidFeatures: [String]
    ) async throws -> TomTomRouteResponse? {
        let urlString = "https://api.tomtom.com/routing/1/calculateRoute/\(origin.latitude),\(origin.longitude):\(destination.latitude),\(destination.longitude)/json"

        guard var components = URLComponents(string: urlString) else { return nil }
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "routeType", value: "fastest"),
            URLQueryItem(name: "traffic", value: "true"),
            URLQueryItem(name: "instructionsType", value: "text"),
            URLQueryItem(name: "language", value: "en-US")
        ]

        if !avoidAreas.isEmpty {
            queryItems.append(URLQueryItem(name: "avoidAreas", value: avoidAreas))
        }

        if !avoidFeatures.isEmpty {
            queryItems.append(URLQueryItem(name: "avoid", value: avoidFeatures.joined(separator: ",")))
        }

        components.queryItems = queryItems
        guard let url = components.url else { return nil }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error("Routing", "TomTom HTTP \(httpResponse.statusCode)")
            }
            return nil
        }

        return try JSONDecoder().decode(TomTomRouteResponse.self, from: data)
    }

    // MARK: - Calculate Safe Route

    func calculateSafeRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, avoiding cameras: [SpeedCamera]) async {
        // Store for preference-driven recalculation
        lastOrigin = origin
        lastDestination = destination
        lastCameras = cameras

        await MainActor.run { isCalculatingRoute = true }
        defer { Task { await MainActor.run { self.isCalculatingRoute = false } } }

        if useMockData {
            do {
                let data = MockRoutingData.tomTomResponseJSON.data(using: .utf8)!
                let result = try JSONDecoder().decode(TomTomRouteResponse.self, from: data)

                await MainActor.run {
                    self.availableRoutes = result.routes
                    self.activeAlternativeRoutes = result.routes.compactMap { route in
                        route.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    }
                    let defaultIndex = result.routes.firstIndex(where: { $0.isZeroCameras }) ?? 0
                    self.selectRoute(at: defaultIndex)
                    Log.info("Routing", "Got \(result.routes.count) routes (mock)")
                }
            } catch {
                Log.error("Routing", "Route calculation failed: \(error)")
            }
            return
        }

        guard !apiKey.isEmpty && apiKey != "YOUR_TOMTOM_API_KEY" else {
            Log.error("Routing", "Missing TomTom API key — cannot calculate route")
            return
        }

        // Build avoid features from current preferences
        var avoidFeatures: [String] = []
        if avoidTolls    { avoidFeatures.append("tollRoads") }
        if avoidHighways { avoidFeatures.append("motorways") }

        let cameraAvoidAreas = cameras.map { $0.boundingBoxForRouting }.joined(separator: "!")

        do {
            // Always fetch the standard route (respects toll/highway prefs)
            var standardRoutes: [TomTomRoute] = []
            if let stdData = try await fetchTomTom(origin: origin, destination: destination, avoidAreas: "", avoidFeatures: avoidFeatures) {
                var mapped = stdData.routes
                for i in 0..<mapped.count {
                    let count = countCameras(on: mapped[i], cameras: cameras)
                    mapped[i].cameraCount = count
                    mapped[i].isSafeRoute = (count == 0)
                }
                standardRoutes = mapped
            }

            // Fetch camera-free route only when avoidSpeedCameras is enabled
            var safeRoutes: [TomTomRoute] = []
            if avoidSpeedCameras {
                if let safeData = try await fetchTomTom(origin: origin, destination: destination, avoidAreas: cameraAvoidAreas, avoidFeatures: avoidFeatures) {
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

            await MainActor.run {
                self.availableRoutes = combined
                self.activeAlternativeRoutes = combined.compactMap { route in
                    route.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                }
                // Default: camera-free if avoiding cameras, else fastest
                let defaultIndex = self.avoidSpeedCameras
                    ? (combined.firstIndex(where: { $0.isSafeRoute }) ?? 0)
                    : 0
                self.selectRoute(at: defaultIndex)
                Log.info("Routing", "Got \(combined.count) routes (tolls:\(self.avoidTolls) hwy:\(self.avoidHighways) cams:\(self.avoidSpeedCameras))")
            }

        } catch {
            Log.error("Routing", "Route calculation failed: \(error.localizedDescription)")
        }
    }
}
