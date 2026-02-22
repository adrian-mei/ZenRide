import Foundation
import CoreLocation

extension CLLocationCoordinate2D {
    /// Distance in meters from another coordinate.
    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let from = CLLocation(latitude: self.latitude, longitude: self.longitude)
        let to = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return from.distance(from: to)
    }
    
    /// Bearing in degrees to another coordinate.
    func bearing(to coordinate: CLLocationCoordinate2D) -> CLLocationDirection {
        let lat1 = self.latitude * .pi / 180
        let lon1 = self.longitude * .pi / 180
        let lat2 = coordinate.latitude * .pi / 180
        let lon2 = coordinate.longitude * .pi / 180
        
        let dLon = lon2 - lon1
        
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        
        let radiansBearing = atan2(y, x)
        let degreesBearing = radiansBearing * 180 / .pi
        
        return (degreesBearing + 360).truncatingRemainder(dividingBy: 360)
    }
    
    /// Coordinate offset by a distance in meters at a given bearing in degrees.
    func coordinate(offsetBy distanceMeters: Double, bearingDegrees: Double) -> CLLocationCoordinate2D {
        let radiusEarth = 6371000.0 // Earth's radius in meters
        
        let lat1 = self.latitude * .pi / 180
        let lon1 = self.longitude * .pi / 180
        let bearing = bearingDegrees * .pi / 180
        let dRadius = distanceMeters / radiusEarth
        
        let lat2 = asin(sin(lat1) * cos(dRadius) + cos(lat1) * sin(dRadius) * cos(bearing))
        let lon2 = lon1 + atan2(sin(bearing) * sin(dRadius) * cos(lat1), cos(dRadius) - sin(lat1) * sin(lat2))
        
        return CLLocationCoordinate2D(latitude: lat2 * 180 / .pi, longitude: lon2 * 180 / .pi)
    }
}
