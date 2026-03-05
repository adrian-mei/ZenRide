import Foundation
import CoreLocation
import MapKit

@MainActor
class HomeBottomSheetViewModel: ObservableObject {
    @Published var activeSheet: BottomSheetChild?
    @Published var questBuilderPreloaded: [QuestWaypoint] = []
    
    // Distance utility
    func distanceToCar(carLocation: CLLocationCoordinate2D, currentLocation: CLLocation?) -> String? {
        guard let loc = currentLocation else { return nil }
        let dist = loc.distance(from: CLLocation(latitude: carLocation.latitude, longitude: carLocation.longitude)) / 1609.34
        return String(format: "%.1f miles away", dist)
    }
}
