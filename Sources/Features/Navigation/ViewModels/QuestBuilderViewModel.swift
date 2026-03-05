import Foundation
import CoreLocation

enum StartLocation: Equatable {
    case currentLocation
    case custom(QuestWaypoint)

    var displayName: String {
        switch self {
        case .currentLocation: return "Current Location"
        case .custom(let wp): return wp.name
        }
    }
}

enum AddStopMode { case stop, start }

@MainActor
class QuestBuilderViewModel: ObservableObject {
    @Published var questName = "My Cozy Commute"
    @Published var waypoints: [QuestWaypoint] = []
    @Published var startLocation: StartLocation = .currentLocation
    
    @Published var showAddStop = false
    @Published var addStopMode: AddStopMode = .stop
    
    var isCustomStart: Bool {
        if case .custom = startLocation { return true }
        return false
    }

    var startLocationCustomLabel: String {
        if case .custom(let wp) = startLocation { return wp.name }
        return "🔍 Choose a Start"
    }
    
    func onAppear(preloadedWaypoints: [QuestWaypoint], preloadedTitle: String) {
        if waypoints.isEmpty && !preloadedWaypoints.isEmpty {
            waypoints = preloadedWaypoints
        }
        if !preloadedTitle.isEmpty && questName == "My Cozy Commute" {
            questName = preloadedTitle
        }
    }
    
    func handleStopAdded(name: String, coord: CLLocationCoordinate2D) {
        let waypoint = QuestWaypoint(name: name, coordinate: coord, icon: "mappin.circle.fill")
        if addStopMode == .start {
            startLocation = .custom(waypoint)
        } else {
            waypoints.append(waypoint)
        }
        showAddStop = false
    }
    
    func removeWaypoint(at index: Int) {
        guard index >= 0 && index < waypoints.count else { return }
        waypoints.remove(at: index)
    }
    
    func startTrip(
        currentLocation: CLLocationCoordinate2D?,
        routingService: RoutingService,
        questStore: QuestStore,
        onStartTrip: ((String, CLLocationCoordinate2D) -> Void)?
    ) {
        var allWaypoints = waypoints
        var startCoord: CLLocationCoordinate2D?

        switch startLocation {
        case .currentLocation:
            startCoord = currentLocation
        case .custom(let wp):
            allWaypoints.insert(wp, at: 0)
            startCoord = wp.coordinate
        }

        let quest = DailyQuest(title: questName, waypoints: allWaypoints)
        questStore.addQuest(quest)
        
        if let (start, end) = routingService.questManager.startQuest(quest, currentLocation: startCoord) {
            Task {
                if let result = try? await QuestNavigationManager.generateLegRouting(from: start, to: end) {
                    routingService.loadLeg(result: result)
                }
            }
        }

        let firstStopName = allWaypoints.first?.name ?? questName
        let firstStopCoord = allWaypoints.first?.coordinate
            ?? startCoord
            ?? Constants.sfCenter

        onStartTrip?(firstStopName, firstStopCoord)
    }
}
