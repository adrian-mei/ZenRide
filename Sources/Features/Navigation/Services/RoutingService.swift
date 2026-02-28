import Foundation
import CoreLocation

enum VehicleMode: String, CaseIterable {
    // Cars
    case car
    case sportsCar
    case electricCar
    case suv
    case truck
    // Two-wheelers
    case motorcycle
    case scooter
    // Human-powered
    case bicycle
    case mountainBike
    // On-foot / micro
    case walking
    case running
    case skateboard

    var icon: String {
        switch self {
        case .car:          return "car.fill"
        case .sportsCar:    return "car.rear.fill"
        case .electricCar:  return "bolt.car.fill"
        case .suv:          return "suv.side.fill"
        case .truck:        return "box.truck.fill"
        case .motorcycle:   return "motorcycle"
        case .scooter:      return "scooter"
        case .bicycle:      return "bicycle"
        case .mountainBike: return "figure.outdoor.cycle"
        case .walking:      return "figure.walk"
        case .running:      return "figure.run"
        case .skateboard:   return "skateboard"
        }
    }

    var displayName: String {
        switch self {
        case .car:          return "Car"
        case .sportsCar:    return "Sports Car"
        case .electricCar:  return "Electric"
        case .suv:          return "SUV"
        case .truck:        return "Truck"
        case .motorcycle:   return "Motorcycle"
        case .scooter:      return "Scooter"
        case .bicycle:      return "Bicycle"
        case .mountainBike: return "Mountain Bike"
        case .walking:      return "Walking"
        case .running:      return "Running"
        case .skateboard:   return "Skateboard"
        }
    }

    /// Camera avoidance default for this mode
    var defaultAvoidCameras: Bool {
        switch self {
        case .motorcycle, .scooter, .sportsCar: return true
        default: return false
        }
    }

    /// Default highway avoidance
    var defaultAvoidHighways: Bool {
        switch self {
        case .bicycle, .mountainBike, .scooter, .walking, .running, .skateboard: return true
        default: return false
        }
    }
}

enum RoutingError: Error {
    case invalidURL
    case noData
    case parsingError
    case apiError(String)
}

struct TomTomRouteResponse: Codable {
    let routes: [TomTomRoute]
}

struct TomTomSummary: Codable {
    let lengthInMeters: Int
    let travelTimeInSeconds: Int
}

struct TomTomGuidance: Codable {
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

struct TomTomInstruction: Codable {
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

struct TomTomRoute: Codable, Identifiable {
    var id = UUID()
    let summary: TomTomSummary
    let tags: [String]?
    let legs: [TomTomLeg]
    let guidance: TomTomGuidance?

    var cameraCount: Int = 0
    var isSafeRoute: Bool = false
    var savedFines: Int { cameraCount * 100 }

    enum CodingKeys: String, CodingKey {
        case id, summary, tags, legs, guidance, cameraCount, isSafeRoute
    }

    var isZeroCameras: Bool {
        tags?.contains("zero_cameras") == true || isSafeRoute || cameraCount == 0
    }

    var isLessTraffic: Bool {
        tags?.contains("less_traffic") == true
    }
    
    var hasTolls: Bool {
        tags?.contains("has_tolls") == true
    }
}

extension TomTomRoute {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.summary = try container.decode(TomTomSummary.self, forKey: .summary)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.legs = try container.decode([TomTomLeg].self, forKey: .legs)
        self.guidance = try container.decodeIfPresent(TomTomGuidance.self, forKey: .guidance)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.cameraCount = try container.decodeIfPresent(Int.self, forKey: .cameraCount) ?? 0
        self.isSafeRoute = try container.decodeIfPresent(Bool.self, forKey: .isSafeRoute) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encode(legs, forKey: .legs)
        try container.encodeIfPresent(guidance, forKey: .guidance)
        try container.encode(cameraCount, forKey: .cameraCount)
        try container.encode(isSafeRoute, forKey: .isSafeRoute)
    }
}

struct TomTomLeg: Codable {
    let points: [TomTomPoint]
}

struct TomTomPoint: Codable {
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
    @Published var instructions: [NavigationInstruction] = []
    @Published var currentInstructionIndex: Int = 0 {
        didSet {
            hasWarned500ft = false
            hasWarned100ft = false
        }
    }
    @Published var isCalculatingRoute = false
    @Published var showReroutePrompt = false

    // MARK: - Multi-Leg Quest State
    @Published var activeQuest: DailyQuest?
    @Published var currentLegIndex: Int = 0
    /// Set to the waypoint count of the most recently completed quest; reset to 0 after XP is awarded.
    @Published var completedQuestWaypointCount: Int = 0

    // MARK: - Vehicle Mode

    @Published var vehicleMode: VehicleMode = .motorcycle {
        didSet {
            guard vehicleMode != oldValue else { return }
            // Apply mode defaults without overriding explicit user toggles
            avoidSpeedCameras = vehicleMode.defaultAvoidCameras
            avoidHighways = vehicleMode.defaultAvoidHighways
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

    // MARK: - Offline Route
    func loadOfflineRoute(_ route: TomTomRoute) {
        Task { @MainActor in
            self.availableRoutes = [route]
            self.activeAlternativeRoutes = [route].compactMap { r in
                r.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            }
            self.selectRoute(at: 0)
            Log.info("Routing", "Loaded offline route from storage.")
        }
    }

    // MARK: - Recalculate with stored params (called on preference change)

    func recalculate() async {
        guard let origin = lastOrigin,
              let destination = lastDestination,
              let cameras = lastCameras else { return }
        await calculateSafeRoute(from: origin, to: destination, avoiding: cameras)
    }

    // MARK: - Rerouting

    private var lastRerouteCheckTime: Date?
    
    func checkReroute(currentLocation: CLLocation) {
        guard activeRoute.count > 1 else { return }
        
        let now = Date()
        if let last = lastRerouteCheckTime, now.timeIntervalSince(last) < 1.0 {
            return // Throttle reroute checks to max 1 per second
        }
        lastRerouteCheckTime = now

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
            if !isCalculatingRoute && !showReroutePrompt {
                Log.info("Routing", "Off route — triggering reroute recalculation")
                DispatchQueue.main.async {
                    self.showReroutePrompt = true
                }
                Task {
                    if let dest = self.lastDestination, let cams = self.lastCameras {
                        await self.calculateSafeRoute(from: currentCoord, to: dest, avoiding: cams)
                    }
                }
            }
        }
    }

    // MARK: - Route Selection

    private func mapTurnType(from tomtomType: String?) -> TurnType {
        guard let type = tomtomType else { return .straight }
        if type == "TURN_LEFT" || type == "KEEP_LEFT" { return .left }
        if type == "TURN_RIGHT" || type == "KEEP_RIGHT" { return .right }
        if type == "ARRIVE" { return .arrive }
        if type.contains("UTURN") { return .uturn }
        return .straight
    }
    
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
                    return NavigationInstruction(
                        text: inst.message ?? "Continue",
                        distanceInMeters: 50,
                        routeOffsetInMeters: trueOffset,
                        pointIndex: inst.pointIndex,
                        turnType: self.mapTurnType(from: inst.instructionType)
                    )
                }
            } else {
                instructions = []
            }
        } else {
            routeDistanceMeters = route.summary.lengthInMeters
            routeTimeSeconds = route.summary.travelTimeInSeconds
            if let tomtom = route.guidance?.instructions {
                instructions = tomtom.map { inst in
                    NavigationInstruction(
                        text: inst.message ?? "Continue",
                        distanceInMeters: 50,
                        routeOffsetInMeters: inst.routeOffsetInMeters,
                        pointIndex: inst.pointIndex,
                        turnType: self.mapTurnType(from: inst.instructionType)
                    )
                }
            } else {
                instructions = []
            }
        }
        currentInstructionIndex = 0
        routeProgressIndex = 0
    }

    // MARK: - Camera Counting

    func countCameras(on route: TomTomRoute, cameras: [SpeedCamera]) -> Int {
        var count = 0
        guard let leg = route.legs.first else { return 0 }
        
        let legPoints = leg.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        guard let first = legPoints.first else { return 0 }
        
        // Find route bounding box for fast pre-filtering
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
        
        // Pad bounding box by ~100 meters (approx 0.001 degrees)
        minLat -= 0.001
        maxLat += 0.001
        minLng -= 0.001
        maxLng += 0.001

        for camera in cameras {
            // Fast bounding box check
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

            // Swift 6 capture workaround: safely bind the value before hopping to the MainActor
            let finalCombined = combined
            await MainActor.run {
                self.availableRoutes = finalCombined
                self.activeAlternativeRoutes = finalCombined.compactMap { route in
                    route.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                }
                // Default: camera-free if avoiding cameras, else fastest
                let defaultIndex = self.avoidSpeedCameras
                    ? (finalCombined.firstIndex(where: { $0.isSafeRoute }) ?? 0)
                    : 0
                self.selectRoute(at: defaultIndex)
                Log.info("Routing", "Got \(finalCombined.count) routes (tolls:\(self.avoidTolls) hwy:\(self.avoidHighways) cams:\(self.avoidSpeedCameras))")
            }

        } catch {
            Log.error("Routing", "Route calculation failed: \(error.localizedDescription)")
        }
    }
}
