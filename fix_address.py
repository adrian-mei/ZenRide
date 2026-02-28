with open('Sources/Features/Destinations/UI/DestinationSearchView.swift', 'r') as f:
    content = f.read()

new_zen = """extension MKPlacemark {
    var zenFormattedAddress: String {
        var components: [String] = []
        var street = ""
        if let subThoroughfare = self.subThoroughfare { street += subThoroughfare + " " }
        if let thoroughfare = self.thoroughfare { street += thoroughfare }
        
        // Use custom title logic if we set it from RecentSearch
        if let dict = self.title, street.isEmpty {
            // We use title field implicitly when name/address falls back for recents, or we can just parse title
        }
        // Let's fallback to the basic properties, as addressDictionary is deprecated. 
        // MKPlacemark's title is often exactly what we want if other properties fail.
        
        if !street.isEmpty { components.append(street) }
        else if let title = self.title {
            // MKPlacemark.title usually contains the formatted address
            return title
        }
        
        if let city = self.locality { components.append(city) }
        else if let area = self.administrativeArea { components.append(area) }
        
        return components.isEmpty ? "Unknown Address" : components.joined(separator: ", ")
    }
}"""

import re
content = re.sub(r'extension MKPlacemark \{.*', new_zen, content, flags=re.DOTALL)

with open('Sources/Features/Destinations/UI/DestinationSearchView.swift', 'w') as f:
    f.write(content)
