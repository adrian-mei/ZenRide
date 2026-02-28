import re

with open('Sources/Features/Destinations/UI/DestinationSearchView.swift', 'r') as f:
    content = f.read()

# Replace search signature and implementation
new_search = """    func search(for query: String, near location: CLLocationCoordinate2D? = nil, recentSearches: [RecentSearch] = []) {
        activeSearch?.cancel()
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
        guard !cleanQuery.isEmpty else {
            searchResults = []; isSearching = false; return
        }
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = cleanQuery
        let center = location ?? CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        request.region = MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
        )
        
        let lowerQuery = cleanQuery.lowercased()
        let matchedRecents = recentSearches.filter { recent in
            recent.name.lowercased().contains(lowerQuery) ||
            recent.subtitle.lowercased().contains(lowerQuery)
        }.map { recent -> MKMapItem in
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: recent.latitude, longitude: recent.longitude),
                                        addressDictionary: ["Street": recent.subtitle])
            let item = MKMapItem(placemark: placemark)
            item.name = recent.name
            return item
        }

        activeSearch = MKLocalSearch(request: request)
        activeSearch?.start { [weak self] response, error in
            DispatchQueue.main.async {
                self?.isSearching = false
                guard let response = response, error == nil else {
                    if !matchedRecents.isEmpty {
                        self?.searchResults = matchedRecents
                    } else {
                        Log.error("Search", "MKLocalSearch failed: \\(error?.localizedDescription ?? "unknown")")
                    }
                    return
                }
                
                let sortedNetworkResults = response.mapItems.sorted { item1, item2 in
                    let name1 = (item1.name ?? "").lowercased()
                    let name2 = (item2.name ?? "").lowercased()
                    
                    let score1 = Self.score(name: name1, query: lowerQuery)
                    let score2 = Self.score(name: name2, query: lowerQuery)
                    
                    if score1 != score2 {
                        return score1 > score2
                    }
                    
                    guard let loc1 = item1.placemark.location, let loc2 = item2.placemark.location else {
                        return false
                    }
                    let centerLoc = CLLocation(latitude: center.latitude, longitude: center.longitude)
                    return loc1.distance(from: centerLoc) < loc2.distance(from: centerLoc)
                }
                
                var finalResults = matchedRecents
                var seenNames = Set<String>()
                for r in matchedRecents {
                    seenNames.insert((r.name ?? "").lowercased())
                }
                
                for item in sortedNetworkResults {
                    let name = (item.name ?? "").lowercased()
                    if !seenNames.contains(name) {
                        finalResults.append(item)
                        seenNames.insert(name)
                    }
                }
                
                self?.searchResults = finalResults
            }
        }
    }
    
    private static func score(name: String, query: String) -> Int {
        if name == query { return 4 }
        if name.hasPrefix(query) { return 3 }
        if name.contains(query) { return 2 }
        return 1
    }"""

content = re.sub(r'    func search\(for query: String, near location: CLLocationCoordinate2D\? = nil\) \{.*?\n    \}', new_search, content, flags=re.DOTALL)

# Replace zenFormattedAddress
new_zen = """    var zenFormattedAddress: String {
        var components: [String] = []
        var street = ""
        if let subThoroughfare = self.subThoroughfare { street += subThoroughfare + " " }
        if let thoroughfare = self.thoroughfare { street += thoroughfare }
        
        // Fallbacks for recent searches with custom AddressDictionary
        if street.isEmpty, let postalAddress = self.postalAddress, !postalAddress.street.isEmpty {
            street = postalAddress.street
        }
        if street.isEmpty, let dict = self.addressDictionary as? [String: Any], let dictStreet = dict["Street"] as? String, !dictStreet.isEmpty {
            street = dictStreet
        }
        
        if !street.isEmpty { components.append(street) }
        
        if let city = self.locality { components.append(city) }
        else if let area = self.administrativeArea { components.append(area) }
        
        return components.isEmpty ? "Unknown Address" : components.joined(separator: ", ")
    }"""

content = re.sub(r'    var zenFormattedAddress: String \{.*?\n    \}', new_zen, content, flags=re.DOTALL)

with open('Sources/Features/Destinations/UI/DestinationSearchView.swift', 'w') as f:
    f.write(content)

