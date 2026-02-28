import CoreLocation

import Foundation

struct CameraDataFile: Codable {
    let cameras: [SpeedCamera]
}

struct SpeedCamera: Codable, Identifiable {
    let id: String
    let street: String
    let from_cross_street: String?
    let to_cross_street: String?
    let speed_limit_mph: Int
    let lat: Double
    let lng: Double
    
    // Convert 50m radius around camera to a bounding box for TomTom API
    var boundingBoxForRouting: String {
        let latDelta = 50.0 / 111111.0
        let lngDelta = 50.0 / (111111.0 * cos(lat * .pi / 180.0))
        
        let minLat = lat - latDelta
        let maxLat = lat + latDelta
        let minLng = lng - abs(lngDelta)
        let maxLng = lng + abs(lngDelta)
        
        // TomTom format: minLon,minLat,maxLon,maxLat
        return "\(minLng),\(minLat),\(maxLng),\(maxLat)"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, street, from_cross_street, to_cross_street, speed_limit_mph, lat, lng
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let idInt = try? container.decode(Int.self, forKey: .id) {
            self.id = String(idInt)
        } else if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = idString
        } else {
            throw DecodingError.typeMismatch(String.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Int for id"))
        }
        self.street = try container.decode(String.self, forKey: .street)
        self.from_cross_street = try container.decodeIfPresent(String.self, forKey: .from_cross_street)
        self.to_cross_street = try container.decodeIfPresent(String.self, forKey: .to_cross_street)
        self.speed_limit_mph = try container.decode(Int.self, forKey: .speed_limit_mph)
        self.lat = try container.decode(Double.self, forKey: .lat)
        self.lng = try container.decode(Double.self, forKey: .lng)
    }
}

class CameraStore: ObservableObject {
    @Published var cameras: [SpeedCamera] = []
    private var hasGeneratedMocks = false
    
    init() {
        loadCameras()
    }
    
    private func loadCameras() {
        guard let url = Bundle.main.url(forResource: "sf_speed_cameras", withExtension: "json") else {
            Log.error("CameraStore", "sf_speed_cameras.json not found in bundle")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let file = try JSONDecoder().decode(CameraDataFile.self, from: data)
            self.cameras = file.cameras
            Log.info("CameraStore", "Loaded \(self.cameras.count) cameras")
        } catch {
            Log.error("CameraStore", "Failed to load cameras: \(error)")
        }
    }
    
    func generateGlobalMockCameras(around location: CLLocationCoordinate2D) {
        guard !hasGeneratedMocks else { return }
        
        // If we are in SF, don't generate mocks, rely on real data
        let sfLoc = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        let distanceToSF = location.distance(to: sfLoc)
        if distanceToSF < 50000 { // within ~50km of SF
            return
        }
        
        hasGeneratedMocks = true
        var mockCameras: [SpeedCamera] = []
        
        // Generate 30 random cameras within a ~5km radius of the user
        let radiusDeg = 5000.0 / 111320.0
        
        for i in 1...30 {
            let randLatOffset = Double.random(in: -radiusDeg...radiusDeg)
            let randLngOffset = Double.random(in: -radiusDeg...radiusDeg)
            
            let mockCamera = SpeedCamera(
                id: "mock_camera_\(i)",
                street: "Local Patrol \(i)",
                from_cross_street: "Intersection \(i)",
                to_cross_street: nil,
                speed_limit_mph: [25, 30, 35, 45].randomElement()!,
                lat: location.latitude + randLatOffset,
                lng: location.longitude + randLngOffset
            )
            mockCameras.append(mockCamera)
        }
        
        DispatchQueue.main.async {
            self.cameras.append(contentsOf: mockCameras)
            Log.info("CameraStore", "Generated \(mockCameras.count) dynamic mock cameras for global support")
        }
    }
}
extension SpeedCamera {
    init(id: String, street: String, from_cross_street: String?, to_cross_street: String?, speed_limit_mph: Int, lat: Double, lng: Double) {
        self.id = id
        self.street = street
        self.from_cross_street = from_cross_street
        self.to_cross_street = to_cross_street
        self.speed_limit_mph = speed_limit_mph
        self.lat = lat
        self.lng = lng
    }
}
