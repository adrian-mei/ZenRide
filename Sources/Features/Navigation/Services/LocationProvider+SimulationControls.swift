import Foundation
import CoreLocation

extension LocationProvider {
    
    func pauseSimulation() {
        guard isSimulating else { return }
        DispatchQueue.main.async {
            self.simulationPaused = true
        }
    }
    
    func resumeSimulation() {
        guard isSimulating else { return }
        DispatchQueue.main.async {
            self.simulationPaused = false
        }
    }
    
    func setSimulationSpeed(_ multiplier: Double) {
        guard isSimulating else { return }
        DispatchQueue.main.async {
            self.simulationSpeedMultiplier = multiplier
        }
    }
}
