import Foundation
import MapKit

class POISearchService {
    func searchPOIs(in region: MKCoordinateRegion) async -> [POIAnnotation] {
        let queries: [(String, POIAnnotation.POIType)] = [
            ("Police", .emergency), ("Fire Station", .emergency),
            ("Hospital", .emergency), ("School", .school), ("Park", .park)
        ]
        
        var newAnns: [POIAnnotation] = []
        
        for (q, t) in queries {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = q
            req.region = region
            
            do {
                let res = try await MKLocalSearch(request: req).start()
                for item in res.mapItems {
                    newAnns.append(POIAnnotation(coordinate: item.placemark.coordinate, title: item.name, subtitle: q, type: t, mapItem: item))
                }
            } catch {
                Log.error("POISearchService", "POI search failed for '\(q)': \(error)")
            }
        }
        
        return newAnns
    }
}
