import Foundation

@MainActor
class SessionSpeedTracker: ObservableObject {
    @Published var speedReadings: [Float] = []
    
    private var speedSampleTimer: Timer?
    private var _sessionTopSpeedMph: Double = 0
    private var sessionSpeedSum: Double = 0
    private var sessionSpeedCount: Int = 0

    var sessionAvgSpeedMph: Double {
        guard sessionSpeedCount > 0 else { return 0 }
        return sessionSpeedSum / Double(sessionSpeedCount)
    }

    var sessionTopSpeedMph: Double { _sessionTopSpeedMph }

    func startTracking(getCurrentSpeed: @escaping () -> Double, onTick: @escaping (Double) -> Void) {
        speedReadings = []
        _sessionTopSpeedMph = 0
        sessionSpeedSum = 0
        sessionSpeedCount = 0
        
        speedSampleTimer?.invalidate()
        speedSampleTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            DispatchQueue.main.async {
                let speed = getCurrentSpeed()
                if speed > 2 {
                    self.speedReadings.append(Float(speed))
                    self.sessionSpeedSum += speed
                    self.sessionSpeedCount += 1
                    if speed > self._sessionTopSpeedMph {
                        self._sessionTopSpeedMph = speed
                    }
                }
                onTick(speed)
            }
        }
    }

    func stopTracking() {
        speedSampleTimer?.invalidate()
        speedSampleTimer = nil
    }

    func reset() {
        stopTracking()
        speedReadings = []
        _sessionTopSpeedMph = 0
        sessionSpeedSum = 0
        sessionSpeedCount = 0
    }
}
