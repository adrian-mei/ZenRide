import Foundation
import Combine

@MainActor
class NavigationAudioCoordinator: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var hasAnnouncedApproach = false
    private let speechService = SpeechService.shared
    
    // We observe the RoutingService to announce instructions
    // This removes the need for SpeechService calls directly inside routing and zone services
    
    func startMonitoring(routingService: RoutingService, bunnyPolice: BunnyPolice) {
        cancellables.removeAll()
        
        // Monitor instruction index changes for turn-by-turn announcements
        routingService.$currentInstructionIndex
            .dropFirst()
            .sink { [weak self] index in
                self?.announceInstruction(routingService: routingService, index: index)
            }
            .store(in: &cancellables)
            
        // Monitor Zone Status for Police warnings
        bunnyPolice.$currentZone
            .dropFirst()
            .sink { [weak self] zone in
                self?.announceZone(zone: zone, isMuted: bunnyPolice.isMuted)
            }
            .store(in: &cancellables)
    }
    
    private func announceInstruction(routingService: RoutingService, index: Int) {
        guard index >= 0 && index < routingService.instructions.count else { return }
        let instruction = routingService.instructions[index]
        speechService.speak(instruction.text)
    }
    
    private func announceZone(zone: ZoneStatus, isMuted: Bool) {
        guard !isMuted else { return }
        
        switch zone {
        case .approach:
            if !hasAnnouncedApproach {
                speechService.speak("There's a speed camera coming up ahead. Please slow down and enjoy the ride.")
                hasAnnouncedApproach = true
            }
        case .danger:
            speechService.speak("Slow down! Camera ahead.")
        case .safe:
            if hasAnnouncedApproach {
                speechService.speak("You've safely passed the camera zone. The road is yours again. Ride safe!")
                hasAnnouncedApproach = false
            }
        }
    }
    func prefetchTTS(for destinationName: String, instructions: [NavigationInstruction], activeQuest: DailyQuest?) {
        var prefetchTexts = [String]()
        let dest = destinationName.isEmpty ? "your destination" : destinationName
        prefetchTexts.append("Route to \(dest) is ready. Let's have a wonderful trip together!")
        prefetchTexts.append("You have arrived at your final destination. Route complete!")
        for instruction in instructions {
            prefetchTexts.append("In 500 feet, \(instruction.text)")
            prefetchTexts.append(instruction.text)
        }
        if let quest = activeQuest {
            for i in 0..<(quest.waypoints.count - 1) {
                let current = quest.waypoints[i].name
                let next = quest.waypoints[i + 1].name
                prefetchTexts.append("Arrived at \(current). Next stop is \(next). Route is ready when you are.")
            }
        }
        speechService.prefetch(texts: prefetchTexts)
    }
}
