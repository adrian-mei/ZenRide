import Foundation
import CoreLocation

struct CameraProximityResult {
    let nearestCamera: SpeedCamera
    let distanceFT: Double
    let zone: ZoneStatus
}

struct ActiveZoneEntry {
    let camera: SpeedCamera
    var speedAtEntry: Double
    var hasSlowedToLimit: Bool = false
    var enteredDangerZone: Bool = false
}

class CameraProximityScanner {
    private let approachThresholdFT: Double = 1000
    private let dangerThresholdFT: Double = 500

    private var lastProximityCheckLocation: CLLocation?

    func scan(
        location: CLLocation,
        cameras: [SpeedCamera]
    ) -> (nearest: SpeedCamera, distance: Double)? {
        guard !cameras.isEmpty else { return nil }

        if let last = lastProximityCheckLocation, location.distance(from: last) < 5 {
            return nil
        }
        lastProximityCheckLocation = location

        var closestDist = Double.greatestFiniteMagnitude
        var closestCam: SpeedCamera?

        // Fast approximate distance pre-filter
        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        let latDegreeInMeters = Constants.metersPerDegree
        let lngDegreeInMeters = Constants.metersPerDegree * cos(lat * .pi / 180.0)

        for camera in cameras {
            let dLat = (camera.lat - lat) * latDegreeInMeters
            let dLng = (camera.lng - lng) * lngDegreeInMeters
            let approxDistMetersSq = dLat * dLat + dLng * dLng

            // 4,000,000 m^2 is 2000 meters squared. Skip real check if far away.
            if approxDistMetersSq < 4_000_000 {
                let camLoc = CLLocationCoordinate2D(latitude: camera.lat, longitude: camera.lng)
                let distance = location.coordinate.distance(to: camLoc) * Constants.metersToFeet // meters → feet
                if distance < closestDist {
                    closestDist = distance
                    closestCam = camera
                }
            }
        }

        guard let nearest = closestCam else { return nil }
        return (nearest, closestDist)
    }

    func determineZone(distanceFT: Double) -> ZoneStatus {
        if distanceFT <= dangerThresholdFT {
            return .danger
        } else if distanceFT <= approachThresholdFT {
            return .approach
        } else {
            return .safe
        }
    }
}
