import Foundation
import CoreLocation

class LocationProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var currentLocation: CLLocation?
    @Published var currentSpeedMPH: Double = 0
    
    @Published var isSimulating: Bool = false
    @Published var simulationCompletedNaturally: Bool = false
    @Published var currentSimulationIndex: Int = 0
    @Published var distanceTraveledInSimulationMeters: Double = 0
    
    private let locationManager = CLLocationManager()
    private var simulationTimer: Timer?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
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
            self.currentSpeedMPH = speedMPS * 2.23694
        }
    }
    
    // MARK: - Simulation
    
    func simulateDrive(along route: [CLLocationCoordinate2D]) {
        guard route.count > 1 else { return }
        
        locationManager.stopUpdatingLocation()
        
        DispatchQueue.main.async {
            self.isSimulating = true
            self.currentSimulationIndex = 0
            self.distanceTraveledInSimulationMeters = 0
            self.simulationCompletedNaturally = false
        }
        
        var currentCoord = route[0]
        var nextIndex = 1
        var distanceTraveledMeters: Double = 0
        
        let targetSpeedMPH: Double = 65
        let targetSpeedMPS = targetSpeedMPH / 2.23694
        
        let tickInterval: TimeInterval = 0.5
        let distancePerTick = targetSpeedMPS * tickInterval
        
        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            // Reached destination logic
            if nextIndex >= route.count {
                DispatchQueue.main.async {
                    self.simulationCompletedNaturally = true
                    self.stopSimulation()
                }
                return
            }
            
            let targetCoord = route[nextIndex]
            let distanceToTarget = currentCoord.distance(to: targetCoord)
            let bearing = currentCoord.bearing(to: targetCoord)
            
            if distanceToTarget <= distancePerTick {
                // Arrived at next node
                distanceTraveledMeters += distanceToTarget
                currentCoord = targetCoord
                
                DispatchQueue.main.async {
                    self.currentSimulationIndex = nextIndex
                    self.distanceTraveledInSimulationMeters = distanceTraveledMeters
                }
                nextIndex += 1
                
                // If we reach the end exactly on this tick
                if nextIndex >= route.count {
                    let mockLocation = CLLocation(
                        coordinate: currentCoord,
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
                currentCoord = currentCoord.coordinate(offsetBy: distancePerTick, bearingDegrees: bearing)
                DispatchQueue.main.async {
                    self.distanceTraveledInSimulationMeters = distanceTraveledMeters
                }
            }
            
            let mockLocation = CLLocation(
                coordinate: currentCoord,
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
            self.currentSpeedMPH = speedMPS * 2.23694
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
