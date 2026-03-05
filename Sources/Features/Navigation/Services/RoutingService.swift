import Foundation
import CoreLocation

enum RoutingError: Error {
    case invalidURL
    case noData
    case parsingError
    case apiError(String)
}

@MainActor
class RoutingService: ObservableObject {
    var questManager = QuestSessionManager()
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

    private let apiClient: TomTomRoutingClient
    private var calculationEngine: RouteCalculationEngine
    var useMockData = false {
        didSet {
            calculationEngine = RouteCalculationEngine(apiClient: apiClient, useMockData: useMockData)
        }
    }

    init(apiClient: TomTomRoutingClient = TomTomRoutingClient(apiKey: Secrets.tomTomAPIKey)) {
        self.apiClient = apiClient
        self.calculationEngine = RouteCalculationEngine(apiClient: apiClient, useMockData: false)
    }

    // MARK: - Offline Route
    func loadOfflineRoute(_ route: TomTomRoute) {
        availableRoutes = [route]
        activeAlternativeRoutes = [route].compactMap { r in
            r.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        }
        selectRoute(at: 0)
        Log.info("Routing", "Loaded offline route from storage.")
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
        let result = RerouteEngine.evaluate(
            currentLocation: currentLocation.coordinate,
            activeRoute: activeRoute,
            routeProgressIndex: routeProgressIndex,
            isCalculatingRoute: isCalculatingRoute,
            showReroutePrompt: showReroutePrompt,
            lastRerouteCheckTime: lastRerouteCheckTime
        )
        
        lastRerouteCheckTime = result.newCheckTime
        
        switch result.action {
        case .none:
            break
        case .advanceIndex(let newIndex):
            routeProgressIndex = newIndex
        case .promptReroute:
            Log.info("Routing", "Off route — triggering reroute recalculation")
            showReroutePrompt = true
            Task {
                if let dest = lastDestination, let cams = lastCameras {
                    await calculateSafeRoute(from: currentLocation.coordinate, to: dest, avoiding: cams)
                }
            }
        }
    }

    // MARK: - Route Selection

    func selectRoute(at index: Int) {
        guard index >= 0 && index < availableRoutes.count else { return }
        selectedRouteIndex = index
        let route = availableRoutes[index]

        let result = RouteSelectionEngine.processSelection(route: route, useMockData: useMockData)
        
        activeRoute = result.activeRoute
        coordinateDistances = result.coordinateDistances
        routeDistanceMeters = result.routeDistanceMeters
        routeTimeSeconds = result.routeTimeSeconds
        instructions = result.instructions
        
        currentInstructionIndex = 0
        routeProgressIndex = 0
    }
    func loadLeg(result: (activeRoute: [CLLocationCoordinate2D], distanceMeters: Int, timeSeconds: Int, instructions: [NavigationInstruction])) {
        self.activeRoute = result.activeRoute
        self.routeDistanceMeters = result.distanceMeters
        self.routeTimeSeconds = result.timeSeconds
        self.instructions = result.instructions
        self.routeProgressIndex = 0
        self.currentInstructionIndex = 0
    }

    // MARK: - Calculate Safe Route
    func calculateSafeRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, avoiding cameras: [SpeedCamera]) async {
        lastOrigin = origin
        lastDestination = destination
        lastCameras = cameras

        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        let result = await calculationEngine.calculateSafeRoute(
            from: origin,
            to: destination,
            avoiding: cameras,
            avoidTolls: avoidTolls,
            avoidHighways: avoidHighways,
            avoidSpeedCameras: avoidSpeedCameras,
            vehicleMode: vehicleMode
        )

        switch result {
        case .success(let routes, let alternativeRoutes, let selectedIndex):
            self.availableRoutes = routes
            self.activeAlternativeRoutes = alternativeRoutes
            self.selectRoute(at: selectedIndex)
            Log.info("Routing", "Got \(routes.count) routes (tolls:\(avoidTolls) hwy:\(avoidHighways) cams:\(avoidSpeedCameras))")

        case .mock(let routes, let alternativeRoutes, let selectedIndex):
            self.availableRoutes = routes
            self.activeAlternativeRoutes = alternativeRoutes
            self.selectRoute(at: selectedIndex)
            Log.info("Routing", "Got \(routes.count) routes (mock)")

        case .failure(let error):
            Log.error("Routing", "Route calculation failed: \(error.localizedDescription)")
        }
    }
}
