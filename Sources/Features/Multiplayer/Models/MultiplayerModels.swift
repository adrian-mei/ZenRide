import Foundation
import CoreLocation

/// Represents a friend driving in the same session/crew
struct CampCrewMember: Identifiable, Codable {
    var id: String // e.g. "user_123"
    var name: String
    var avatarURL: String?
    var coordinate: CLLocationCoordinate2D
    var heading: Double
    var speedMph: Double
    var etaSeconds: Int?
    var distanceToDestinationMeters: Int?
    var activeRoute: [CLLocationCoordinate2D]?
    var lastUpdated: Date

    enum CodingKeys: String, CodingKey {
        case id, name, avatarURL, latitude, longitude, heading, speedMph, etaSeconds, distanceToDestinationMeters, activeRoute, lastUpdated
    }

    init(id: String, name: String, avatarURL: String? = nil, coordinate: CLLocationCoordinate2D, heading: Double, speedMph: Double, etaSeconds: Int? = nil, distanceToDestinationMeters: Int? = nil, activeRoute: [CLLocationCoordinate2D]? = nil, lastUpdated: Date = Date()) {
        self.id = id
        self.name = name
        self.avatarURL = avatarURL
        self.coordinate = coordinate
        self.heading = heading
        self.speedMph = speedMph
        self.etaSeconds = etaSeconds
        self.distanceToDestinationMeters = distanceToDestinationMeters
        self.activeRoute = activeRoute
        self.lastUpdated = lastUpdated
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatarURL = try container.decodeIfPresent(String.self, forKey: .avatarURL)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lng = try container.decode(Double.self, forKey: .longitude)
        coordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        heading = try container.decode(Double.self, forKey: .heading)
        speedMph = try container.decode(Double.self, forKey: .speedMph)
        etaSeconds = try container.decodeIfPresent(Int.self, forKey: .etaSeconds)
        distanceToDestinationMeters = try container.decodeIfPresent(Int.self, forKey: .distanceToDestinationMeters)
        if let routeCoords = try container.decodeIfPresent([[Double]].self, forKey: .activeRoute) {
            activeRoute = routeCoords.map { CLLocationCoordinate2D(latitude: $0[0], longitude: $0[1]) }
        } else {
            activeRoute = nil
        }
        lastUpdated = try container.decode(Date.self, forKey: .lastUpdated)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(avatarURL, forKey: .avatarURL)
        try container.encode(coordinate.latitude, forKey: .latitude)
        try container.encode(coordinate.longitude, forKey: .longitude)
        try container.encode(heading, forKey: .heading)
        try container.encode(speedMph, forKey: .speedMph)
        try container.encodeIfPresent(etaSeconds, forKey: .etaSeconds)
        try container.encodeIfPresent(distanceToDestinationMeters, forKey: .distanceToDestinationMeters)
        if let route = activeRoute {
            let encodedRoute = route.map { [$0.latitude, $0.longitude] }
            try container.encode(encodedRoute, forKey: .activeRoute)
        }
        try container.encode(lastUpdated, forKey: .lastUpdated)
    }
}

/// Represents an active multiplayer session sharing a destination (and optionally a multi-stop route)
struct CampCrewSession: Identifiable, Codable {
    var id: String
    var destinationName: String
    var destinationCoordinate: CLLocationCoordinate2D
    /// Multi-stop shared route. Empty means free-cruise / single destination.
    var waypoints: [QuestWaypoint]
    var members: [CampCrewMember]
    var isHost: Bool
    /// Whether the route has been saved for offline use by the host.
    var isOfflineSaved: Bool

    enum CodingKeys: String, CodingKey {
        case id, destinationName, latitude, longitude, waypoints, members, isHost, isOfflineSaved
    }

    init(
        id: String,
        destinationName: String,
        destinationCoordinate: CLLocationCoordinate2D,
        waypoints: [QuestWaypoint] = [],
        members: [CampCrewMember] = [],
        isHost: Bool = false,
        isOfflineSaved: Bool = false
    ) {
        self.id = id
        self.destinationName = destinationName
        self.destinationCoordinate = destinationCoordinate
        self.waypoints = waypoints
        self.members = members
        self.isHost = isHost
        self.isOfflineSaved = isOfflineSaved
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        destinationName = try container.decode(String.self, forKey: .destinationName)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lng = try container.decode(Double.self, forKey: .longitude)
        destinationCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        waypoints = (try? container.decode([QuestWaypoint].self, forKey: .waypoints)) ?? []
        members = try container.decode([CampCrewMember].self, forKey: .members)
        isHost = try container.decode(Bool.self, forKey: .isHost)
        isOfflineSaved = (try? container.decode(Bool.self, forKey: .isOfflineSaved)) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(destinationName, forKey: .destinationName)
        try container.encode(destinationCoordinate.latitude, forKey: .latitude)
        try container.encode(destinationCoordinate.longitude, forKey: .longitude)
        try container.encode(waypoints, forKey: .waypoints)
        try container.encode(members, forKey: .members)
        try container.encode(isHost, forKey: .isHost)
        try container.encode(isOfflineSaved, forKey: .isOfflineSaved)
    }
}
