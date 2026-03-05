import MapKit

extension MKPlacemark {
    var zenFormattedAddress: String {
        var components: [String] = []
        var street = ""
        if let subThoroughfare = self.subThoroughfare { street += subThoroughfare + " " }
        if let thoroughfare = self.thoroughfare { street += thoroughfare }

        if !street.isEmpty { components.append(street) } else if let title = self.title {
            return title
        }

        if let city = self.locality { components.append(city) } else if let area = self.administrativeArea { components.append(area) }

        return components.isEmpty ? "Unknown Address" : components.joined(separator: ", ")
    }
}
