import Foundation
import CoreLocation

class SimulationEngine {
    private var simulationTimer: Timer?
    private var currentSimulationCoord: CLLocationCoordinate2D?
    private var nextSimulationIndex: Int = 0
    private var simulationRoute: [CLLocationCoordinate2D] = []
    
    var onTick: ((CLLocation, Double, Int) -> Void)?
    var onComplete: (() -> Void)?

    func start(route: [CLLocationCoordinate2D], speedMPH: Double = 35, speedMultiplier: Double = 1.0) {
        guard route.count > 1 else { return }
        
        self.simulationRoute = route
        self.currentSimulationCoord = route[0]
        self.nextSimulationIndex = 1
        var distanceTraveledMeters: Double = 0

        let targetSpeedMPH: Double = speedMPH
        let tickInterval: TimeInterval = 0.1

        simulationTimer?.invalidate()
        simulationTimer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            guard let currentCoord = self.currentSimulationCoord else { return }

            let targetSpeedMPS = (targetSpeedMPH / Constants.mpsToMph) * speedMultiplier
            let distancePerTick = targetSpeedMPS * tickInterval

            if self.nextSimulationIndex >= self.simulationRoute.count {
                self.onComplete?()
                return
            }

            let targetCoord = self.simulationRoute[self.nextSimulationIndex]
            let distanceToTarget = currentCoord.distance(to: targetCoord)
            let bearing = currentCoord.bearing(to: targetCoord)
            var newCoord = currentCoord

            if distanceToTarget <= distancePerTick {
                distanceTraveledMeters += distanceToTarget
                newCoord = targetCoord
                self.nextSimulationIndex += 1

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
                    self.onTick?(mockLocation, distanceTraveledMeters, self.nextSimulationIndex - 1)
                    self.onComplete?()
                    return
                }
            } else {
                distanceTraveledMeters += distancePerTick
                newCoord = currentCoord.coordinate(offsetBy: distancePerTick, bearingDegrees: bearing)
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
            self.onTick?(mockLocation, distanceTraveledMeters, self.nextSimulationIndex - 1)
        }
    }
    
    func stop() {
        simulationTimer?.invalidate()
        simulationTimer = nil
    }
}
