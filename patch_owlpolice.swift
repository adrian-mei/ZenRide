import Foundation

let path = "Sources/OwlPolice.swift"
var content = try! String(contentsOfFile: path, encoding: .utf8)

// Add UIkit import if not present
if !content.contains("import UIKit") {
    content = content.replacingOccurrences(of: "import Foundation", with: "import Foundation\nimport UIKit")
}

// Add dangerCooldowns
content = content.replacingOccurrences(of: "private var exitCooldowns: [String: Date] = [:]", with: "private var exitCooldowns: [String: Date] = [:]\n    private var dangerCooldowns: [String: Date] = [:]")

// Modify updateZone
content = content.replacingOccurrences(of: """
    private func updateZone(distance: Double, camera: SpeedCamera) {
        let previousZone = currentZone
        
        if distance <= dangerThresholdFT {
            currentZone = .danger
        } else if distance <= approachThresholdFT {
            currentZone = .approach
            if previousZone == .safe {
                triggerApproachWarning(for: camera)
            }
        } else {
""", with: """
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
""")

// Add triggerSpeedingDangerWarning
let dangerFunc = """
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
        synthesizer.speak(utterance)
    }

    private func triggerApproachWarning(for camera: SpeedCamera) {
"""
content = content.replacingOccurrences(of: "    private func triggerApproachWarning(for camera: SpeedCamera) {", with: dangerFunc)

// Clear dangerCooldowns in stopSimulation and simulateDrive
content = content.replacingOccurrences(of: "self.exitCooldowns.removeAll()", with: "self.exitCooldowns.removeAll()\n            self.dangerCooldowns.removeAll()")


try! content.write(toFile: path, atomically: true, encoding: .utf8)
