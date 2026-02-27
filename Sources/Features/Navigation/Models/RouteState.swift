import Foundation

enum RouteState {
    case search // Or "Idle/Quest Selection"
    case building // NEW: User is actively adding waypoints to a Quest
    case reviewing // Looking at the map overview before starting
    case navigating // Actively driving
    case legComplete // Arrived at an intermediate waypoint (e.g. Coffee shop)
}
