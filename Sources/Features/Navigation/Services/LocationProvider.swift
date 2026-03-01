import Foundation
import CoreLocation

class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var currentSpeedMPH: Double = 0
    
    @Published var isSimulating: Bool = false
    @Published var simulationPaused: Bool = false
    @Published var simulationSpeedMultiplier: Double = 1.0
    @Published var simulationCompletedNaturally: Bool = false
    @Published var currentSimulationIndex: Int = 0
    @Published var distanceTraveledInSimulationMeters: Double = 0
    
    private let locationManager = CLLocationManager()
    private var simulationTimer: Timer?
    private var simulationRoute: [CLLocationCoordinate2D] = []
    private var currentSimulationCoord: CLLocationCoordinate2D?
    private var nextSimulationIndex: Int = 1
    
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
        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentSpeedMPH = speedMPS * Constants.mpsToMph
        }
    }
    
    // MARK: - Simulation
    
    func simulateDrive(along route: [CLLocationCoordinate2D]) {
        guard route.count > 1 else { return }
        
        locationManager.stopUpdatingLocation()
        
        DispatchQueue.main.async {
            self.isSimulating = true
            self.simulationPaused = false
            self.simulationSpeedMultiplier = 1.0
            self.currentSimulationIndex = 0
            self.distanceTraveledInSimulationMeters = 0
            self.simulationCompletedNaturally = false
        }
        
        self.simulationRoute = route
        self.currentSimulationCoord = route[0]
        self.nextSimulationIndex = 1
        var distanceTraveledMeters: Double = 0
        
        let targetSpeedMPH: Double = 65
        
        let tickInterval: TimeInterval = 0.1 // Increase tick rate from 0.5s to 0.1s for 10FPS map updates
        
        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard !self.simulationPaused else { return }
            guard let currentCoord = self.currentSimulationCoord else { return }
            
            // Apply speed multiplier
            let targetSpeedMPS = (targetSpeedMPH / Constants.mpsToMph) * self.simulationSpeedMultiplier
            let distancePerTick = targetSpeedMPS * tickInterval
            
            // Reached destination logic
            if self.nextSimulationIndex >= self.simulationRoute.count {
                DispatchQueue.main.async {
                    self.simulationCompletedNaturally = true
                    self.stopSimulation()
                }
                return
            }
            
            let targetCoord = self.simulationRoute[self.nextSimulationIndex]
            
            // Math helper logic to avoid 'distance' not found error (using CLLocation distance logic)
            let distanceToTarget = currentCoord.distance(to: targetCoord)
            
            let bearing = currentCoord.bearing(to: targetCoord)
            
            var newCoord = currentCoord
            
            if distanceToTarget <= distancePerTick {
                // Arrived at next node
                distanceTraveledMeters += distanceToTarget
                newCoord = targetCoord
                
                DispatchQueue.main.async {
                    self.currentSimulationIndex = self.nextSimulationIndex
                    self.distanceTraveledInSimulationMeters = distanceTraveledMeters
                }
                self.nextSimulationIndex += 1
                
                // If we reach the end exactly on this tick
                if self.nextSimulationIndex >= self.simulationRoute.count {
                    let mockLocation = CLLocation(
                        coordinate: newCoord,
                        altitude: 0,
                        horizontalAccuracy: 5,
                        verticalAccuracy: 5,
                        course: bearing,
                        speed: targetSpeedMPS,
                        timestamp: Date()
                    )
                    self.processSimulatedLocation(mockLocation)
                    
                    DispatchQueue.main.async {
                        self.simulationCompletedNaturally = true
                        self.stopSimulation()
                    }
                    return
                }
            } else {
                // Move towards target
                distanceTraveledMeters += distancePerTick
                newCoord = currentCoord.coordinate(offsetBy: distancePerTick, bearingDegrees: bearing)
                DispatchQueue.main.async {
                    self.distanceTraveledInSimulationMeters = distanceTraveledMeters
                }
            }
            
            self.currentSimulationCoord = newCoord
            
            let mockLocation = CLLocation(
                coordinate: newCoord,
                altitude: 0,
                horizontalAccuracy: 5,
                verticalAccuracy: 5,
                course: bearing,
                speed: targetSpeedMPS,
                timestamp: Date()
            )
            self.processSimulatedLocation(mockLocation)
        }
    }
    
    private func processSimulatedLocation(_ location: CLLocation) {
        let speedMPS = max(0, location.speed)
        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentSpeedMPH = speedMPS * Constants.mpsToMph
        }
    }
    
    func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        
        DispatchQueue.main.async {
            self.isSimulating = false
            self.currentSpeedMPH = 0
            self.currentSimulationIndex = 0
            self.distanceTraveledInSimulationMeters = 0
            self.locationManager.startUpdatingLocation()
        }
    }
}
