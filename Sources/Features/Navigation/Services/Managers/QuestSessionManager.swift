import MapKit
import Combine

import Foundation
import CoreLocation

@MainActor
class QuestSessionManager: ObservableObject {
    @Published var activeQuest: DailyQuest?
    @Published var currentLegIndex: Int = 0
    @Published var completedQuestWaypointCount: Int = 0

    var currentStopName: String {
        guard let quest = activeQuest, currentLegIndex >= -1 && currentLegIndex < quest.waypoints.count else { return "" }
        if currentLegIndex == -1 { return quest.waypoints[0].name }
        return quest.waypoints[min(currentLegIndex + 1, quest.waypoints.count - 1)].name
    }

    var totalStopsInQuest: Int { activeQuest?.waypoints.count ?? 0 }
    
    var currentStopNumber: Int {
        if currentLegIndex == -1 { return 0 }
        return currentLegIndex + 1
    }

    func startQuest(_ quest: DailyQuest, currentLocation: CLLocationCoordinate2D?) -> (CLLocationCoordinate2D, CLLocationCoordinate2D)? {
        guard !quest.waypoints.isEmpty else { return nil }

        self.activeQuest = quest

        if let current = currentLocation {
            let firstWaypoint = quest.waypoints[0].coordinate
            if current.distance(to: firstWaypoint) > 100 {
                self.currentLegIndex = -1
                SpeechService.shared.speak("Starting adventure: \(quest.title). First, let's head to \(quest.waypoints[0].name).")
                return (current, firstWaypoint)
            }
        }

        self.currentLegIndex = 0
        guard quest.waypoints.count > 1 else {
            SpeechService.shared.speak("You have arrived at \(quest.waypoints[0].name).")
            return nil
        }

        let startCoord = currentLocation ?? quest.waypoints[0].coordinate
        let destinationCoord = quest.waypoints[1].coordinate

        SpeechService.shared.speak("Starting adventure: \(quest.title). Heading to \(quest.waypoints[1].name).")
        return (startCoord, destinationCoord)
    }

    func advanceToNextLeg(currentLocation: CLLocationCoordinate2D) -> (CLLocationCoordinate2D, CLLocationCoordinate2D)? {
        guard let quest = activeQuest else { return nil }

        if currentLegIndex == -1 {
            currentLegIndex = 0
        } else {
            currentLegIndex += 1
        }

        if currentLegIndex >= quest.waypoints.count - 1 {
            self.completedQuestWaypointCount = quest.waypoints.count
            self.activeQuest = nil
            SpeechService.shared.speak("You have arrived at your final destination. Adventure complete!")
            return nil
        }

        let nextDestination = quest.waypoints[currentLegIndex + 1].coordinate
        SpeechService.shared.speak("Arrived at \(quest.waypoints[currentLegIndex].name). Next stop is \(quest.waypoints[currentLegIndex + 1].name).")

        return (currentLocation, nextDestination)
    }
}
