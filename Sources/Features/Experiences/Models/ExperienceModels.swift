import Foundation
import CoreLocation

// MARK: - Catalog Model

struct ExperienceCatalog: Codable {
    let catalogId: String
    let version: String
    let experiences: [ExperienceSummary]
}

struct ExperienceSummary: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let durationMinutes: Int
    let thumbnailUrl: String?
    let filename: String
}

// MARK: - Route Model

struct ExperienceRoute: Codable, Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let durationMinutes: Int
    let city: String
    let region: String
    let stops: [ExperienceStop]
}

struct ExperienceStop: Codable, Identifiable {
    let id: String
    let order: Int
    let name: String
    let latitude: Double
    let longitude: Double
    let description: String
    let imageUrls: [String]?
    let isSkippable: Bool
    let canNavigateDirectly: Bool
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}
