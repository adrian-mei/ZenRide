import Foundation

let path = "Sources/OwlPolice.swift"
var contents = try! String(contentsOfFile: path, encoding: .utf8)

// 1. Add camerasPassedThisRide
contents = contents.replacingOccurrences(of: "@Published var isSimulating: Bool = false", with: """
    @Published var isSimulating: Bool = false
    @Published var camerasPassedThisRide: Int = 0
    
    func resetRideStats() {
        camerasPassedThisRide = 0
    }
""")

// 2. Update triggerApproachWarning
let oldApproach = """
    private func triggerApproachWarning(for camera: SpeedCamera) {
        let now = Date()
        if let last = approachCooldowns[camera.id], now.timeIntervalSince(last) < (cooldownMinutes * 60) {
            return // Cooldown active
        }
        approachCooldowns[camera.id] = now
        
        let speech = "Hoo... Officer Owl here. Sleepy speed trap ahead on \\(camera.street). Let's keep a gentle pace at \\(camera.speed_limit_mph) miles per hour."
        speak(speech)
    }
"""

let newApproach = """
    private func triggerApproachWarning(for camera: SpeedCamera) {
        let now = Date()
        if let last = approachCooldowns[camera.id], now.timeIntervalSince(last) < (cooldownMinutes * 60) {
            return // Cooldown active
        }
        approachCooldowns[camera.id] = now
        
        let speech = "Hoo... Officer Owl here. There's a sleepy speed trap down this stretch. Roll off the throttle, let's just enjoy the breeze for a minute."
        speak(speech)
    }
"""
contents = contents.replacingOccurrences(of: oldApproach, with: newApproach)

// 3. Update triggerExitMessage
let oldExit = """
    private func triggerExitMessage(for camera: SpeedCamera) {
        let now = Date()
        if let last = exitCooldowns[camera.id], now.timeIntervalSince(last) < (cooldownMinutes * 60) {
            return // Cooldown active
        }
        exitCooldowns[camera.id] = now
        
        let speech = "We've passed the trap. The road is clear. Enjoy the breeze."
        speak(speech)
    }
"""

let newExit = """
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
"""
contents = contents.replacingOccurrences(of: oldExit, with: newExit)

try! contents.write(toFile: path, atomically: true, encoding: .utf8)
print("Updated OwlPolice.swift successfully.")
