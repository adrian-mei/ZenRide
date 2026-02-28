import Foundation
import CoreLocation

enum ZoneStatus {
    case safe
    case approach
    case danger
}

class BunnyPolice: ObservableObject {
    private let speech = SpeechService.shared
    
    // MARK: - Published State
    
    @Published var nearestCamera: SpeedCamera?
    @Published var currentZone: ZoneStatus = .safe
    @Published var camerasPassedThisRide: Int = 0
    @Published var zenScore: Int = 100
    @Published var isMuted: Bool = false
    
    // MARK: - Navigation Session Tracking
    
    @Published var speedReadings: [Float] = []
    @Published var cameraZoneEvents: [CameraZoneEvent] = []
    
    // Internal tracking (non-published to prevent UI thrashing)
    private var distanceToNearestFT: Double = 0
    
    private var speedSampleTimer: Timer?
    private var _sessionTopSpeedMph: Double = 0
    private var sessionSpeedSum: Double = 0
    private var sessionSpeedCount: Int = 0
    
    // Per-camera approach/danger tracking
    private struct ActiveZoneEntry {
        let camera: SpeedCamera
        var speedAtEntry: Double
        var hasSlowedToLimit: Bool = false
        var enteredDangerZone: Bool = false
    }
    private var activeZoneEntry: ActiveZoneEntry?
    
    var sessionAvgSpeedMph: Double {
        guard sessionSpeedCount > 0 else { return 0 }
        return sessionSpeedSum / Double(sessionSpeedCount)
    }
    
    var sessionTopSpeedMph: Double { _sessionTopSpeedMph }
    
    var cameras: [SpeedCamera] = []
    private var lastSpeedMPH: Double = 0
    
    private var approachCooldowns: [String: Date] = [:]
    private var exitCooldowns: [String: Date] = [:]
    private var dangerCooldowns: [String: Date] = [:]
    private var lastProximityCheckLocation: CLLocation?
    
    private let approachThresholdFT: Double = 1000
    private let dangerThresholdFT: Double = 500
    private let cooldownMinutes: Double = 3.0
    
    func startNavigationSession() {
        speedReadings = []
        cameraZoneEvents = []
        activeZoneEntry = nil
        _sessionTopSpeedMph = 0
        sessionSpeedSum = 0
        sessionSpeedCount = 0
        startSpeedSampling()
        Log.info("BunnyPolice", "Navigation session started")
    }
    
    func stopNavigationSession() {
        stopSpeedSampling()
        finalizeActiveZoneEntry()
        Log.info("BunnyPolice", "Navigation session stopped. Readings: \(speedReadings.count), Events: \(cameraZoneEvents.count)")
    }
    
    func resetRideStats() {
        camerasPassedThisRide = 0
        zenScore = 100
        speedReadings = []
        cameraZoneEvents = []
        activeZoneEntry = nil
        _sessionTopSpeedMph = 0
        sessionSpeedSum = 0
        sessionSpeedCount = 0
        currentZone = .safe
        nearestCamera = nil
        distanceToNearestFT = 0
        lastProximityCheckLocation = nil
        approachCooldowns = [:]
        dangerCooldowns = [:]
        exitCooldowns = [:]
    }
    
    private func startSpeedSampling() {
        speedSampleTimer?.invalidate()
        speedSampleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let speed = self.lastSpeedMPH
            if speed > 2 {
                self.speedReadings.append(Float(speed))
                self.sessionSpeedSum += speed
                self.sessionSpeedCount += 1
                if speed > self._sessionTopSpeedMph {
                    self._sessionTopSpeedMph = speed
                }
            }
            // Safety net: track slowdown even when proximity check hasn't fired
            if let entry = self.activeZoneEntry,
               entry.enteredDangerZone,
               let camera = self.nearestCamera,
               self.currentZone == .danger,
               speed <= Double(camera.speed_limit_mph) {
                self.activeZoneEntry?.hasSlowedToLimit = true
            }
        }
    }
    
    private func stopSpeedSampling() {
        speedSampleTimer?.invalidate()
        speedSampleTimer = nil
    }
    
    // MARK: - Update Engine
    
    func processLocation(_ location: CLLocation, speedMPH: Double) {
        self.lastSpeedMPH = speedMPH
        checkProximity(to: location, speedMPH: speedMPH)
    }
    
    private func checkProximity(to location: CLLocation, speedMPH: Double) {
        guard !cameras.isEmpty else { return }
        
        if let last = lastProximityCheckLocation, location.distance(from: last) < 5 {
            return
        }
        lastProximityCheckLocation = location
        
        var closestDist = Double.greatestFiniteMagnitude
        var closestCam: SpeedCamera?
        
        // Fast approximate distance pre-filter
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        let latDegreeInMeters = 111320.0
        let lngDegreeInMeters = 111320.0 * cos(lat * .pi / 180.0)
        
        for camera in cameras {
            let dLat = (camera.lat - lat) * latDegreeInMeters
            let dLng = (camera.lng - lng) * lngDegreeInMeters
            let approxDistMetersSq = dLat * dLat + dLng * dLng
            
            // 4,000,000 m^2 is 2000 meters squared. Skip real check if far away.
            if approxDistMetersSq < 4_000_000 {
                let camLoc = CLLocationCoordinate2D(latitude: camera.lat, longitude: camera.lng)
                let distance = location.coordinate.distance(to: camLoc) * 3.28084 // meters → feet
                if distance < closestDist {
                    closestDist = distance
                    closestCam = camera
                }
            }
        }
        
        guard let nearest = closestCam else { return }
        
        DispatchQueue.main.async {
            // Only update if something visually or logically changed to avoid rapid SwiftUI invalidations
            if self.nearestCamera?.id != nearest.id || abs(self.distanceToNearestFT - closestDist) > 5.0 {
                self.nearestCamera = nearest
                self.distanceToNearestFT = closestDist
                self.updateZone(distance: closestDist, camera: nearest, speedNow: speedMPH)
            }
        }
    }
    
    private func updateZone(distance: Double, camera: SpeedCamera, speedNow: Double) {
        let previousZone = currentZone
        
        var newZone = previousZone
        
        if distance <= dangerThresholdFT {
            newZone = .danger
            
            // Begin zone entry tracking if not started, or promote from approach
            if activeZoneEntry == nil {
                activeZoneEntry = ActiveZoneEntry(camera: camera, speedAtEntry: speedNow, enteredDangerZone: true)
            } else if !activeZoneEntry!.enteredDangerZone {
                activeZoneEntry!.speedAtEntry = speedNow
                activeZoneEntry!.enteredDangerZone = true
            }
            
            // Check if user has slowed to limit inside danger zone
            if speedNow <= Double(camera.speed_limit_mph) {
                activeZoneEntry?.hasSlowedToLimit = true
            }
            
            if speedNow > Double(camera.speed_limit_mph) + 3.0 {
                triggerSpeedingDangerWarning(for: camera)
            }
            
        } else if distance <= approachThresholdFT {
            newZone = .approach
            
            // Start tracking on approach (may or may not enter danger)
            if activeZoneEntry == nil {
                activeZoneEntry = ActiveZoneEntry(camera: camera, speedAtEntry: speedNow, enteredDangerZone: false)
            }
            
            if previousZone == .safe {
                triggerApproachWarning(for: camera)
            }
        } else {
            newZone = .safe
            if previousZone == .approach || previousZone == .danger {
                triggerExitMessage(for: camera)
                finalizeActiveZoneEntry()
            }
        }
        
        if newZone != previousZone {
            currentZone = newZone
        }
    }
    
    private func finalizeActiveZoneEntry() {
        guard let entry = activeZoneEntry else { return }
        defer { activeZoneEntry = nil }
        
        // Only record an event if we actually reached the danger zone
        guard entry.enteredDangerZone else { return }
        
        let outcome: CameraOutcome = entry.hasSlowedToLimit ? .saved : .potentialTicket
        
        let streetName: String
        if let cross = entry.camera.from_cross_street {
            streetName = "\(entry.camera.street) @ \(cross)"
        } else {
            streetName = entry.camera.street
        }
        
        let event = CameraZoneEvent(
            cameraId: entry.camera.id,
            cameraStreet: streetName,
            speedLimitMph: entry.camera.speed_limit_mph,
            userSpeedAtZone: entry.speedAtEntry,
            didSlowDown: entry.hasSlowedToLimit,
            outcome: outcome
        )
        cameraZoneEvents.append(event)
        Log.info("BunnyPolice", "Camera zone event: \(streetName) — \(outcome.rawValue)")
    }
    
    // MARK: - Alerts
    
    private func triggerSpeedingDangerWarning(for camera: SpeedCamera) {
        let now = Date()
        if let last = dangerCooldowns[camera.id], now.timeIntervalSince(last) < 10.0 {
            return
        }
        dangerCooldowns[camera.id] = now
        
        DispatchQueue.main.async {
            self.zenScore = max(0, self.zenScore - 5)
        }
        
        if !isMuted { speech.speak("Slow down! Camera ahead.") }
    }
    
    private func triggerApproachWarning(for camera: SpeedCamera) {
        let now = Date()
        if let last = approachCooldowns[camera.id], now.timeIntervalSince(last) < (cooldownMinutes * 60) {
            return
        }
        approachCooldowns[camera.id] = now
        
        let speech = "There's a speed camera coming up ahead. Please slow down and enjoy the ride."
        speak(speech)
    }
    
    private func triggerExitMessage(for camera: SpeedCamera) {
        let now = Date()
        if let last = exitCooldowns[camera.id], now.timeIntervalSince(last) < (cooldownMinutes * 60) {
            return
        }
        exitCooldowns[camera.id] = now
        
        DispatchQueue.main.async {
            self.camerasPassedThisRide += 1
        }
        
        let speech = "You've safely passed the camera zone. The road is yours again. Ride safe!"
        speak(speech)
    }
    
    public func speak(_ text: String) {
        if !isMuted { speech.speak(text) }
    }
}
