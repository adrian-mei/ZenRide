import Foundation
import CoreLocation

enum ZoneStatus {
    case safe
    case approach
    case danger
}

@MainActor
class BunnyPolice: ObservableObject {
    private let speech = SpeechService.shared

    // MARK: - Published State

    @Published var nearestCamera: SpeedCamera?
    @Published var currentZone: ZoneStatus = .safe
    @Published var camerasPassedThisRide: Int = 0
    @Published var zenScore: Int = 100
    @Published var isMuted: Bool = false

    // MARK: - Navigation Session Tracking

    var speedTracker = SessionSpeedTracker()
    var speedReadings: [Float] { speedTracker.speedReadings }
    @Published var cameraZoneEvents: [CameraZoneEvent] = []

    // Internal tracking (non-published to prevent UI thrashing)
    private var distanceToNearestFT: Double = 0




    private var activeZoneEntry: ActiveZoneEntry?

    var sessionAvgSpeedMph: Double { speedTracker.sessionAvgSpeedMph }
    var sessionTopSpeedMph: Double { speedTracker.sessionTopSpeedMph }

    var cameras: [SpeedCamera] = []
    private var lastSpeedMPH: Double = 0

    private var approachCooldowns: [String: Date] = [:]
    private var exitCooldowns: [String: Date] = [:]
    private var dangerCooldowns: [String: Date] = [:]
    private let scanner = CameraProximityScanner()

    private let cooldownMinutes: Double = 3.0

    func startNavigationSession() {
        speedTracker.reset()
        cameraZoneEvents = []
        activeZoneEntry = nil
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
        speedTracker.reset()
        cameraZoneEvents = []
        activeZoneEntry = nil
        currentZone = .safe
        nearestCamera = nil
        distanceToNearestFT = 0
        approachCooldowns = [:]
        dangerCooldowns = [:]
        exitCooldowns = [:]
    }

    private func startSpeedSampling() {
        speedTracker.startTracking { [weak self] in
            return self?.lastSpeedMPH ?? 0
        } onTick: { [weak self] (speed: Double) in
            guard let self = self else { return }
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
        speedTracker.stopTracking()
    }

    // MARK: - Update Engine

    func processLocation(_ location: CLLocation, speedMPH: Double) {
        self.lastSpeedMPH = speedMPH
        checkProximity(to: location, speedMPH: speedMPH)
    }

    private func checkProximity(to location: CLLocation, speedMPH: Double) {
        guard let scanResult = scanner.scan(location: location, cameras: cameras) else { return }
        
        let nearest = scanResult.nearest
        let closestDist = scanResult.distance

        // Only update if something visually or logically changed to avoid rapid SwiftUI invalidations
        if nearestCamera?.id != nearest.id || abs(distanceToNearestFT - closestDist) > 5.0 {
            nearestCamera = nearest
            distanceToNearestFT = closestDist
            updateZone(distance: closestDist, camera: nearest, speedNow: speedMPH)
        }
    }

    private func updateZone(distance: Double, camera: SpeedCamera, speedNow: Double) {
        let previousZone = currentZone

        var newZone = previousZone

        newZone = scanner.determineZone(distanceFT: distance)
        
        if newZone == .danger {

            // Begin zone entry tracking if not started, or promote from approach
            if activeZoneEntry == nil {
                activeZoneEntry = ActiveZoneEntry(camera: camera, speedAtEntry: speedNow, enteredDangerZone: true)
            } else if let currentEntry = activeZoneEntry, !currentEntry.enteredDangerZone {
                activeZoneEntry?.speedAtEntry = speedNow
                activeZoneEntry?.enteredDangerZone = true
            }

            // Check if user has slowed to limit inside danger zone
            if speedNow <= Double(camera.speed_limit_mph) {
                activeZoneEntry?.hasSlowedToLimit = true
            }

            if speedNow > Double(camera.speed_limit_mph) + 3.0 {
                let now = Date()
                if let last = dangerCooldowns[camera.id] {
                    if now.timeIntervalSince(last) >= 10.0 {
                        dangerCooldowns[camera.id] = now
                        zenScore = max(0, zenScore - 5)
                    }
                } else {
                    dangerCooldowns[camera.id] = now
                    zenScore = max(0, zenScore - 5)
                }
            }

        } else if newZone == .approach {

            // Start tracking on approach (may or may not enter danger)
            if activeZoneEntry == nil {
                activeZoneEntry = ActiveZoneEntry(camera: camera, speedAtEntry: speedNow, enteredDangerZone: false)
            }

            if previousZone == .safe {
                let now = Date()
                if let last = approachCooldowns[camera.id] {
                    if now.timeIntervalSince(last) >= (cooldownMinutes * 60) {
                        approachCooldowns[camera.id] = now
                    }
                } else {
                    approachCooldowns[camera.id] = now
                }
            }
        } else {
            newZone = .safe
            if previousZone == .approach || previousZone == .danger {
                let now = Date()
                if let last = exitCooldowns[camera.id] {
                    if now.timeIntervalSince(last) >= (cooldownMinutes * 60) {
                        exitCooldowns[camera.id] = now
                        camerasPassedThisRide += 1
                    }
                } else {
                    exitCooldowns[camera.id] = now
                    camerasPassedThisRide += 1
                }
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

// Audio announcements are now handled by NavigationAudioCoordinator observing currentZone

    public func speak(_ text: String) {
        if !isMuted { speech.speak(text) }
    }
}
