import Foundation
import UIKit
import CoreLocation
import AVFoundation

enum ZoneStatus {
    case safe
    case approach // 1000 ft
    case danger   // 500 ft
}

class OwlPolice: NSObject, ObservableObject, CLLocationManagerDelegate {
    let locationManager = CLLocationManager()
    private let synthesizer = AVSpeechSynthesizer()
    
    @Published var currentSpeedMPH: Double = 0
    @Published var isMuted: Bool = false
    @Published var nearestCamera: SpeedCamera?
    @Published var distanceToNearestFT: Double = 0
    @Published var currentZone: ZoneStatus = .safe
    @Published var currentLocation: CLLocation?
        @Published var isSimulating: Bool = false
    @Published var camerasPassedThisRide: Int = 0
    
    func resetRideStats() {
        camerasPassedThisRide = 0
    }
    
    var cameras: [SpeedCamera] = []
    
    // Anti-spam cooldown timers (CameraID -> Last Alert Time)
    private var approachCooldowns: [String: Date] = [:]
    private var exitCooldowns: [String: Date] = [:]
    private var dangerCooldowns: [String: Date] = [:]
    private var simulationTimer: Timer?
    @Published var currentSimulationIndex: Int = 0
    @Published var distanceTraveledInSimulationMeters: Double = 0
    
    private let approachThresholdFT: Double = 1000
    private let dangerThresholdFT: Double = 500
    private let cooldownMinutes: Double = 3.0
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.requestWhenInUseAuthorization()
        
        // Setup audio session for ducking
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voicePrompt, options: [.duckOthers, .mixWithOthers])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session category.")
        }
    }
    
    func startPatrol(with cameras: [SpeedCamera]) {
        self.cameras = cameras
        locationManager.startUpdatingLocation()
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.startUpdatingLocation()
        default:
            break
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard !isSimulating else { return } // Ignore real location during simulation
        guard let location = locations.last else { return }
        
        processLocation(location)
    }
    
    private func processLocation(_ location: CLLocation) {
        DispatchQueue.main.async {
            self.currentLocation = location
        }
        
        // Update speed
        let speedMPS = max(0, location.speed) // negative if invalid
        
        DispatchQueue.main.async {
            self.currentSpeedMPH = speedMPS * 2.23694
        }
        
        checkProximity(to: location)
    }
    
    // MARK: - Simulation
    
    func simulateDrive(along route: [CLLocationCoordinate2D]) {
        guard route.count > 1 else { return }
        
        locationManager.stopUpdatingLocation() // Pause real GPS
        
        DispatchQueue.main.async {
            self.isSimulating = true
            self.currentSimulationIndex = 0
            self.distanceTraveledInSimulationMeters = 0 // Reset distance
            self.approachCooldowns.removeAll() // Clear cooldowns so we can test repeatedly
            self.exitCooldowns.removeAll()
            self.dangerCooldowns.removeAll()
        }
        
        // Configuration
        let targetSpeedMPS: Double = 20.1 // ~45 mph
        let tickInterval: TimeInterval = 0.05 // 20 updates per second for smooth movement
        let distancePerTick = targetSpeedMPS * tickInterval
        
        var currentCoord = route[0]
        var nextIndex = 1
        var distanceTraveledMeters: Double = 0
        
        // Timer fires every tickInterval
        simulationTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            DispatchQueue.main.async {
                guard nextIndex < route.count else {
                    self.stopSimulation()
                    return
                }
                
                let targetCoord = route[nextIndex]
                let distanceToTarget = currentCoord.distance(to: targetCoord)
                
                let bearing = currentCoord.bearing(to: targetCoord)
                
                if distanceToTarget <= distancePerTick {
                    // We've reached or passed the target in this tick
                    distanceTraveledMeters += distanceToTarget
                    currentCoord = targetCoord
                    self.currentSimulationIndex = nextIndex
                    nextIndex += 1
                } else {
                    // Move towards the target
                    distanceTraveledMeters += distancePerTick
                    currentCoord = currentCoord.coordinate(offsetBy: distancePerTick, bearingDegrees: bearing)
                }
                
                self.distanceTraveledInSimulationMeters = distanceTraveledMeters
                
                let mockLocation = CLLocation(
                    coordinate: currentCoord,
                    altitude: 0,
                    horizontalAccuracy: 5,
                    verticalAccuracy: 5,
                    course: bearing, // Set course so map can rotate to face movement
                    speed: targetSpeedMPS,
                    timestamp: Date()
                )
                
                self.processLocation(mockLocation)
            }
        }
    }
    
    func stopSimulation() {
        simulationTimer?.invalidate()
        simulationTimer = nil
        
        DispatchQueue.main.async {
            self.isSimulating = false
            self.currentSpeedMPH = 0
            self.locationManager.startUpdatingLocation() // Resume real GPS
        }
    }
    
    private func checkProximity(to location: CLLocation) {
        guard !cameras.isEmpty else { return }
        
        // Find nearest camera
        var closestDist = Double.greatestFiniteMagnitude
        var closestCam: SpeedCamera? = nil
        
        for camera in cameras {
            let camLoc = CLLocation(latitude: camera.lat, longitude: camera.lng)
            let distance = location.distance(from: camLoc) * 3.28084 // Convert meters to feet
            if distance < closestDist {
                closestDist = distance
                closestCam = camera
            }
        }
        
        guard let nearest = closestCam else { return }
        
        DispatchQueue.main.async {
            self.nearestCamera = nearest
            self.distanceToNearestFT = closestDist
            
            self.updateZone(distance: closestDist, camera: nearest)
        }
    }
    
    private func updateZone(distance: Double, camera: SpeedCamera) {
        let previousZone = currentZone
        
        if distance <= dangerThresholdFT {
            currentZone = .danger
            
            // Danger speeding alert
            if currentSpeedMPH > Double(camera.speed_limit_mph) + 3.0 { // 3mph tolerance before screaming
                triggerSpeedingDangerWarning(for: camera)
            }
            
        } else if distance <= approachThresholdFT {
            currentZone = .approach
            if previousZone == .safe {
                triggerApproachWarning(for: camera)
            }
        } else {
            currentZone = .safe
            if previousZone == .approach || previousZone == .danger {
                triggerExitMessage(for: camera)
            }
        }
    }
    
    private func triggerSpeedingDangerWarning(for camera: SpeedCamera) {
        let now = Date()
        // Warn at most every 10 seconds while in danger zone
        if let last = dangerCooldowns[camera.id], now.timeIntervalSince(last) < 10.0 {
            return
        }
        dangerCooldowns[camera.id] = now
        
        DispatchQueue.main.async {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        }
        
        let utterance = AVSpeechUtterance(string: "Slow down! Camera ahead.")
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.55 // Faster, urgent pace
        utterance.pitchMultiplier = 1.2
        if !isMuted { synthesizer.speak(utterance) }
    }

    private func triggerApproachWarning(for camera: SpeedCamera) {
        let now = Date()
        if let last = approachCooldowns[camera.id], now.timeIntervalSince(last) < (cooldownMinutes * 60) {
            return // Cooldown active
        }
        approachCooldowns[camera.id] = now
        
        let speech = "Hoo... Officer Owl here. There's a sleepy speed trap down this stretch. Roll off the throttle, let's just enjoy the breeze for a minute."
        speak(speech)
    }
    
    private func triggerExitMessage(for camera: SpeedCamera) {
        let now = Date()
        if let last = exitCooldowns[camera.id], now.timeIntervalSince(last) < (cooldownMinutes * 60) {
            return // Cooldown active
        }
        exitCooldowns[camera.id] = now
        
        DispatchQueue.main.async {
            self.camerasPassedThisRide += 1
        }
        
        let speech = "Trap cleared. The road is yours again. Ride safe."
        speak(speech)
    }
    
    public func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.45 // Calm, slower pace
        utterance.pitchMultiplier = 1.1 // Slightly higher, friendly
        if !isMuted { synthesizer.speak(utterance) }
    }
}
