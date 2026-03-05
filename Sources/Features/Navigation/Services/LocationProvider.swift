import Foundation
import CoreLocation

class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var currentSpeedMPH: Double = 0
    @Published var ecoScore: Double = 100.0

    @Published var isSimulating: Bool = false
    @Published var simulationPaused: Bool = false
    @Published var simulationSpeedMultiplier: Double = 1.0
    @Published var simulationCompletedNaturally: Bool = false
    @Published var currentSimulationIndex: Int = 0
    @Published var distanceTraveledInSimulationMeters: Double = 0
    @Published var currentStreetName: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastGeocodeLocation: CLLocation?

    private var lastSpeedUpdateDate: Date?
    private var lastSpeedValueMPH: Double?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 2.0 // Only update if moved > 2 meters to avoid UI thrash on noisy GPS
        #if os(iOS)
        locationManager.allowsBackgroundLocationUpdates = true
        locationManager.showsBackgroundLocationIndicator = true
        #endif
        locationManager.requestAlwaysAuthorization()
    }

    func startUpdatingLocation() {
        guard !isSimulating else { return }
        locationManager.startUpdatingLocation()
    }

    func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if !isSimulating {
                manager.startUpdatingLocation()
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isSimulating else { return }
        guard let location = locations.last else { return }
        processLiveLocation(location)
    }

    private func processLiveLocation(_ location: CLLocation) {
        let speedMPS = max(0, location.speed)
        let newSpeedMph = speedMPS * Constants.mpsToMph
        updateEcoScore(newSpeedMph: newSpeedMph)

        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentSpeedMPH = newSpeedMph
        }
        updateStreetName(for: location)
    }

    // MARK: - Simulation

    private let simulationEngine = SimulationEngine()

    func simulateDrive(along route: [CLLocationCoordinate2D], speedMPH: Double = 35) {
        guard route.count > 1 else { return }
        locationManager.stopUpdatingLocation()

        isSimulating = true
        simulationPaused = false
        simulationSpeedMultiplier = 1.0
        currentSimulationIndex = 0
        distanceTraveledInSimulationMeters = 0
        simulationCompletedNaturally = false

        simulationEngine.onTick = { [weak self] mockLocation, distanceTraveled, index in
            guard let self = self, !self.simulationPaused else { return }
            self.distanceTraveledInSimulationMeters = distanceTraveled
            self.currentSimulationIndex = index
            self.processSimulatedLocation(mockLocation)
        }
        
        simulationEngine.onComplete = { [weak self] in
            guard let self = self else { return }
            self.simulationCompletedNaturally = true
            self.stopSimulation()
        }

        simulationEngine.start(route: route, speedMPH: speedMPH, speedMultiplier: simulationSpeedMultiplier)
    }
    private func processSimulatedLocation(_ location: CLLocation) {
        let speedMPS = max(0, location.speed)
        let newSpeedMph = speedMPS * Constants.mpsToMph
        updateEcoScore(newSpeedMph: newSpeedMph)

        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentSpeedMPH = newSpeedMph
        }
        updateStreetName(for: location)
    }

    private func updateEcoScore(newSpeedMph: Double) {
        let now = Date()
        if let lastT = lastSpeedUpdateDate, let lastV = lastSpeedValueMPH {
            let dt = now.timeIntervalSince(lastT)
            if dt > 0.5 {
                let dv = newSpeedMph - lastV
                let accel = dv / dt // mph per second
                var newScore = ecoScore

                if accel > 4.0 || accel < -5.0 { // Hard accel or braking
                    newScore -= 2.0
                } else if abs(accel) < 1.0 && newSpeedMph > 10.0 { // Smooth driving
                    newScore += 0.5
                }

                let clampedScore = max(0.0, min(100.0, newScore))

                DispatchQueue.main.async {
                    self.ecoScore = clampedScore
                }

                lastSpeedUpdateDate = now
                lastSpeedValueMPH = newSpeedMph
            }
        } else {
            lastSpeedUpdateDate = now
            lastSpeedValueMPH = newSpeedMph
        }
    }

    private func updateStreetName(for location: CLLocation) {
        if let lastLoc = lastGeocodeLocation, location.distance(from: lastLoc) < 50 {
            return
        }
        lastGeocodeLocation = location
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            if let placemark = placemarks?.first, let street = placemark.thoroughfare {
                DispatchQueue.main.async {
                    self?.currentStreetName = street
                }
            }
        }
    }

    func stopSimulation() {
        simulationEngine.stop()

        DispatchQueue.main.async {
            self.isSimulating = false
            self.currentSpeedMPH = 0
            self.currentSimulationIndex = 0
            self.distanceTraveledInSimulationMeters = 0
            self.locationManager.startUpdatingLocation()
        }
    }
}
