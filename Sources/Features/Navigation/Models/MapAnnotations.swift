import MapKit

// MARK: - Route Overlay

class BorderedPolyline: MKPolyline {
    var isBorder = false
}

// MARK: - Car / Player Annotation

class SimulatedCarAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var vehicleType: VehicleType

    init(coordinate: CLLocationCoordinate2D, vehicleType: VehicleType) {
        self.coordinate = coordinate
        self.vehicleType = vehicleType
        super.init()
    }
}

// MARK: - Quest Waypoint Annotation

class QuestWaypointAnnotation: NSObject, MKAnnotation {
    let id: UUID
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let wp: QuestWaypoint
    let index: Int

    init(waypoint: QuestWaypoint, index: Int) {
        self.id = waypoint.id
        self.wp = waypoint
        self.index = index
        self.coordinate = waypoint.coordinate
        self.title = waypoint.name
        super.init()
    }
}

// MARK: - Speed Camera Annotation

class CameraAnnotation: NSObject, MKAnnotation {
    let id: String
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?

    init(camera: SpeedCamera) {
        self.id = camera.id
        self.coordinate = CLLocationCoordinate2D(latitude: camera.lat, longitude: camera.lng)
        self.title = "Speed Camera"
        self.subtitle = "Speed Limit: \(camera.speed_limit_mph) MPH"
        super.init()
    }
}

// MARK: - Multiplayer Friend Annotation

class FriendAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var memberId: String
    var memberName: String
    var memberAvatar: String?
    var memberHeading: Double

    init(memberId: String, memberName: String, memberAvatar: String?,
         coordinate: CLLocationCoordinate2D, heading: Double) {
        self.memberId = memberId
        self.memberName = memberName
        self.memberAvatar = memberAvatar
        self.coordinate = coordinate
        self.memberHeading = heading
        super.init()
    }
}

// MARK: - Point of Interest Annotation

class POIAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let type: POIType
    let mapItem: MKMapItem?

    enum POIType { case emergency, school, park, freeway }

    init(coordinate: CLLocationCoordinate2D, title: String?, subtitle: String?,
         type: POIType, mapItem: MKMapItem? = nil) {
        self.coordinate = coordinate
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.mapItem = mapItem
        super.init()
    }
}
