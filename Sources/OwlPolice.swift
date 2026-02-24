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
    private let speech = SpeechService.shared

    // MARK: - Published State

    @Published var currentSpeedMPH: Double = 0
    @Published var isMuted: Bool = false
    @Published var nearestCamera: SpeedCamera?
    @Published var distanceToNearestFT: Double = 0
    @Published var currentZone: ZoneStatus = .safe
    @Published var currentLocation: CLLocation?
    @Published var isSimulating: Bool = false
    @Published var camerasPassedThisRide: Int = 0
    @Published var zenScore: Int = 100

    // MARK: - Navigation Session Tracking

    @Published var speedReadings: [Float] = []
    @Published var cameraZoneEvents: [CameraZoneEvent] = []

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

    // MARK: - Simulation State

    var cameras: [SpeedCamera] = []

    private var approachCooldowns: [String: Date] = [:]
    private var exitCooldowns: [String: Date] = [:]
    private var dangerCooldowns: [String: Date] = [:]
    private var simulationTimer: Timer?
    private var lastProximityCheckLocation: CLLocation?
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

        // Audio session is owned by SpeechService.shared — configured on first access.
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
        guard !isSimulating else { return }
        guard let location = locations.last else { return }
        processLocation(location)
    }

    private func processLocation(_ location: CLLocation) {
        let speedMPS = max(0, location.speed)

        DispatchQueue.main.async {
            self.currentLocation = location
            self.currentSpeedMPH = speedMPS * 2.23694
        }

        checkProximity(to: location)
    }

    // MARK: - Navigation Session

    func startNavigationSession() {
        speedReadings = []
        cameraZoneEvents = []
        activeZoneEntry = nil
        _sessionTopSpeedMph = 0
        sessionSpeedSum = 0
        sessionSpeedCount = 0
        startSpeedSampling()
        Log.info("OwlPolice", "Navigation session started")
    }

    func stopNavigationSession() {
        stopSpeedSampling()
        finalizeActiveZoneEntry()
        Log.info("OwlPolice", "Navigation session stopped. Readings: \(speedReadings.count), Events: \(cameraZoneEvents.count)")
    }

    private func startSpeedSampling() {
        speedSampleTimer?.invalidate()
        speedSampleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let speed = self.currentSpeedMPH
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

    func resetRideStats() {
        camerasPassedThisRide = 0
        zenScore = 100
        speedReadings = []
        cameraZoneEvents = []
        activeZoneEntry = nil
        _sessionTopSpeedMph = 0
        sessionSpeedSum = 0
        sessionSpeedCount = 0
        // Reset zone/camera state so next ride starts clean
        currentZone = .safe
        nearestCamera = nil
        distanceToNearestFT = 0
        lastProximityCheckLocation = nil
        approachCooldowns = [:]
        dangerCooldowns = [:]
        exitCooldowns = [:]
    }

    // MARK: - Simulation

    func simulateDrive(along route: [CLLocationCoordinate2D]) {
        guard route.count > 1 else { return }

        locationManager.stopUpdatingLocation()

        DispatchQueue.main.async {
            self.isSimulating = true
            self.currentSimulationIndex = 0
            self.distanceTraveledInSimulationMeters = 0
            self.approachCooldowns.removeAll()
            self.exitCooldowns.removeAll()
            self.dangerCooldowns.removeAll()
        }

        let targetSpeedMPS: Double = 20.1 // ~45 mph
        let tickInterval: TimeInterval = 1.0 / 60.0
        let distancePerTick = targetSpeedMPS * tickInterval

        var currentCoord = route[0]
        var nextIndex = 1
        var distanceTraveledMeters: Double = 0

        simulationTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }

            DispatchQueue.main.async {
                guard self.isSimulating else {
                    timer.invalidate()
                    return
                }
                guard nextIndex < route.count else {
                    self.stopSimulation()
                    return
                }

                let targetCoord = route[nextIndex]
                let distanceToTarget = currentCoord.distance(to: targetCoord)
                let bearing = currentCoord.bearing(to: targetCoord)

                if distanceToTarget <= distancePerTick {
                    distanceTraveledMeters += distanceToTarget
                    currentCoord = targetCoord
                    self.currentSimulationIndex = nextIndex
                    nextIndex += 1
                } else {
                    distanceTraveledMeters += distancePerTick
                    currentCoord = currentCoord.coordinate(offsetBy: distancePerTick, bearingDegrees: bearing)
                }

                self.distanceTraveledInSimulationMeters = distanceTraveledMeters

                let mockLocation = CLLocation(
                    coordinate: currentCoord,
                    altitude: 0,
                    horizontalAccuracy: 5,
                    verticalAccuracy: 5,
                    course: bearing,
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
            self.currentSimulationIndex = 0
            self.distanceTraveledInSimulationMeters = 0
            self.locationManager.startUpdatingLocation()
        }
    }

    // MARK: - Proximity

    private func checkProximity(to location: CLLocation) {
        guard !cameras.isEmpty else { return }

        if let last = lastProximityCheckLocation, location.distance(from: last) < 5 {
            return
        }
        lastProximityCheckLocation = location

        var closestDist = Double.greatestFiniteMagnitude
        var closestCam: SpeedCamera?

        for camera in cameras {
            let camLoc = CLLocation(latitude: camera.lat, longitude: camera.lng)
            let distance = location.distance(from: camLoc) * 3.28084 // meters → feet
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
        let speedNow = currentSpeedMPH

        if distance <= dangerThresholdFT {
            currentZone = .danger

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
            currentZone = .approach

            // Start tracking on approach (may or may not enter danger)
            if activeZoneEntry == nil {
                activeZoneEntry = ActiveZoneEntry(camera: camera, speedAtEntry: speedNow, enteredDangerZone: false)
            }

            if previousZone == .safe {
                triggerApproachWarning(for: camera)
            }
        } else {
            currentZone = .safe
            if previousZone == .approach || previousZone == .danger {
                triggerExitMessage(for: camera)
                finalizeActiveZoneEntry()
            }
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
        Log.info("OwlPolice", "Camera zone event: \(streetName) — \(outcome.rawValue)")
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

            #if os(iOS)
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
            #endif
        }

        if !isMuted { speech.speak("Slow down! Camera ahead.") }
    }

    private func triggerApproachWarning(for camera: SpeedCamera) {
        let now = Date()
        if let last = approachCooldowns[camera.id], now.timeIntervalSince(last) < (cooldownMinutes * 60) {
            return
        }
        approachCooldowns[camera.id] = now

        let speech = "Hoo... Officer Owl here. There's a sleepy speed trap down this stretch. Roll off the throttle, let's just enjoy the breeze for a minute."
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

        let speech = "Trap cleared. The road is yours again. Ride safe."
        speak(speech)
    }

    public func speak(_ text: String) {
        if !isMuted { speech.speak(text) }
    }
}
