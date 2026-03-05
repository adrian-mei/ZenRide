import CoreLocation

extension KeyedDecodingContainer {
    func decodeCoordinate(latKey: Key, lngKey: Key) throws -> CLLocationCoordinate2D {
        let lat = try decode(Double.self, forKey: latKey)
        let lng = try decode(Double.self, forKey: lngKey)
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

extension KeyedEncodingContainer {
    mutating func encodeCoordinate(
        _ coord: CLLocationCoordinate2D, latKey: Key, lngKey: Key
    ) throws {
        try encode(coord.latitude, forKey: latKey)
        try encode(coord.longitude, forKey: lngKey)
    }
}
