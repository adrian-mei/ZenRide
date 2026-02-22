import Foundation
import CoreLocation

enum RoutingError: Error {
    case invalidURL
    case noData
    case parsingError
    case apiError(String)
}

struct TomTomRouteResponse: Decodable {
    let routes: [TomTomRoute]
}

struct TomTomSummary: Decodable {
    let lengthInMeters: Int
    let travelTimeInSeconds: Int
}

struct TomTomGuidance: Decodable {
    let instructions: [TomTomInstruction]?
}

struct TomTomInstruction: Decodable {
    let routeOffsetInMeters: Int
    let travelTimeInSeconds: Int
    let pointIndex: Int
    let instructionType: String?
    let street: String?
    let message: String?
}

struct TomTomRoute: Decodable, Identifiable {
    var id = UUID()
    let summary: TomTomSummary
    let tags: [String]?
    let legs: [TomTomLeg]
    let guidance: TomTomGuidance?
    
    // Custom properties to track cameras
    var cameraCount: Int = 0
    var isSafeRoute: Bool = false
    var savedFines: Int {
        return cameraCount * 100 // $100 per camera ticket
    }
    
    enum CodingKeys: String, CodingKey {
        case summary, tags, legs, guidance
    }
    
    var isZeroCameras: Bool {
        tags?.contains("zero_cameras") == true || isSafeRoute || cameraCount == 0
    }
    
    var isLessTraffic: Bool {
        tags?.contains("less_traffic") == true
    }
}

struct TomTomLeg: Decodable {
    let points: [TomTomPoint]
}

struct TomTomPoint: Decodable {
    let latitude: Double
    let longitude: Double
}

class RoutingService: ObservableObject {
    @Published var availableRoutes: [TomTomRoute] = []
    @Published var selectedRouteIndex: Int = 0
    
    @Published var activeRoute: [CLLocationCoordinate2D] = []
        @Published var activeAlternativeRoutes: [[CLLocationCoordinate2D]] = []
    
    @Published var routeProgressIndex: Int = 0
    
    @Published var routeDistanceMeters: Int = 0
    @Published var routeTimeSeconds: Int = 0
    @Published var instructions: [TomTomInstruction] = []
    @Published var currentInstructionIndex: Int = 0
    @Published var isCalculatingRoute = false

    private let apiKey = Secrets.tomTomAPIKey
    var useMockData = false
    
    func checkReroute(currentLocation: CLLocation) {
        guard activeRoute.count > 1 else { return }
        
        let currentCoord = currentLocation.coordinate
        
        // Find the closest segment on the active route from the current progress segment onwards
        var minDistance = Double.greatestFiniteMagnitude
        var closestSegmentIndex = routeProgressIndex
        
        // Look ahead a reasonable amount (e.g., next 50 segments) to avoid snapping backward or to a parallel segment
        let searchEndIndex = min(routeProgressIndex + 50, activeRoute.count - 1)
        
        if routeProgressIndex < activeRoute.count - 1 {
            for i in routeProgressIndex..<searchEndIndex {
                let start = activeRoute[i]
                let end = activeRoute[i + 1]
                let distance = currentCoord.distanceToSegment(start: start, end: end)
                if distance < minDistance {
                    minDistance = distance
                    closestSegmentIndex = i
                }
            }
            
            // Update progress index to trim the route behind us
            DispatchQueue.main.async {
                if closestSegmentIndex > self.routeProgressIndex {
                    self.routeProgressIndex = closestSegmentIndex
                }
            }
        } else {
            minDistance = currentCoord.distance(to: activeRoute.last!)
        }
        
        let closestDistance = minDistance
        
        // If we are more than 100 meters away from the closest segment of our route, we missed a turn!
        if closestDistance > 100 {
            Log.info("Routing", "Off route — switching to next alternative")
            
            // In a real app, we would fetch a new route from TomTom here using currentLocation as the new origin.
            // For this prototype, we will just simulate a successful reroute by picking the next alternative route if available,
            // or reversing the route as a mock "recalculation".
            
            DispatchQueue.main.async {
                // Auto-reroute seamlessly without user prompt
                if self.availableRoutes.count > 1 {
                    let newIndex = (self.selectedRouteIndex + 1) % self.availableRoutes.count
                    self.selectRoute(at: newIndex)
                }
            }
        }
    }
    
    func selectRoute(at index: Int) {
        guard index >= 0 && index < availableRoutes.count else { return }
        selectedRouteIndex = index
        let route = availableRoutes[index]
        
        var totalCalculatedDistance = 0.0
        var coordinateDistances: [Double] = [0.0] // Cumulative distance at each point index
        
        if let firstLeg = route.legs.first {
            let coordinates = firstLeg.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
            activeRoute = coordinates
            
            // Calculate accurate cumulative geometric distances
            for i in 1..<coordinates.count {
                let dist = coordinates[i-1].distance(to: coordinates[i])
                totalCalculatedDistance += dist
                coordinateDistances.append(totalCalculatedDistance)
            }
        }
        
        // When using mock data, overwrite the fixed mocked distances with actual calculated geometric distances
        if useMockData {
            routeDistanceMeters = Int(totalCalculatedDistance)
            // Keep travel time roughly proportional (assume avg 15 m/s)
            routeTimeSeconds = Int(totalCalculatedDistance / 15.0)
            
            // Update the offset of each instruction to match its true map distance
            if let oldInstructions = route.guidance?.instructions {
                instructions = oldInstructions.map { inst in
                    let trueOffset = inst.pointIndex < coordinateDistances.count ? Int(coordinateDistances[inst.pointIndex]) : Int(totalCalculatedDistance)
                    return TomTomInstruction(
                        routeOffsetInMeters: trueOffset,
                        travelTimeInSeconds: Int(Double(trueOffset) / 15.0),
                        pointIndex: inst.pointIndex,
                        instructionType: inst.instructionType,
                        street: inst.street,
                        message: inst.message
                    )
                }
            } else {
                instructions = []
            }
        } else {
            routeDistanceMeters = route.summary.lengthInMeters
            routeTimeSeconds = route.summary.travelTimeInSeconds
            instructions = route.guidance?.instructions ?? []
        }
                currentInstructionIndex = 0
        routeProgressIndex = 0
    }
    

    private func countCameras(on route: TomTomRoute, cameras: [SpeedCamera]) -> Int {
        var count = 0
        guard let leg = route.legs.first else { return 0 }
        
        for camera in cameras {
            let camLoc = CLLocationCoordinate2D(latitude: camera.lat, longitude: camera.lng)
            // If any point in the route is within 50 meters of the camera, it counts as a hit
            for point in leg.points {
                let pLoc = CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude)
                if pLoc.distance(to: camLoc) < 70 { // using 70 meters to be safe
                    count += 1
                    break // count this camera once
                }
            }
        }
        return count
    }
    
    private func fetchTomTom(origin: CLLocationCoordinate2D, destination: CLLocationCoordinate2D, avoiding avoidAreasParam: String) async throws -> TomTomRouteResponse? {
        var urlString = "https://api.tomtom.com/routing/1/calculateRoute/\(origin.latitude),\(origin.longitude):\(destination.latitude),\(destination.longitude)/json"
        
        guard var components = URLComponents(string: urlString) else { return nil }
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "routeType", value: "fastest"),
            URLQueryItem(name: "traffic", value: "true")
        ]
        
        if !avoidAreasParam.isEmpty {
            components.queryItems?.append(URLQueryItem(name: "avoidAreas", value: avoidAreasParam))
        }
        
        guard let url = components.url else { return nil }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error("Routing", "TomTom HTTP \(httpResponse.statusCode)")
            }
            return nil
        }
        
        return try JSONDecoder().decode(TomTomRouteResponse.self, from: data)
    }

    func calculateSafeRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, avoiding cameras: [SpeedCamera]) async {
        await MainActor.run { isCalculatingRoute = true }
        defer { Task { await MainActor.run { self.isCalculatingRoute = false } } }

        if useMockData {
            do {
                let data = MockRoutingData.tomTomResponseJSON.data(using: .utf8)!
                let result = try JSONDecoder().decode(TomTomRouteResponse.self, from: data)
                
                DispatchQueue.main.async {
                    self.availableRoutes = result.routes
                    
                    self.activeAlternativeRoutes = result.routes.compactMap { route in
                        route.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                    }
                    
                    // Select the zero_cameras route by default if available, else first
                    let defaultIndex = result.routes.firstIndex(where: { $0.isZeroCameras }) ?? 0
                    self.selectRoute(at: defaultIndex)
                    
                    Log.info("Routing", "Got \(result.routes.count) routes")
                }
            } catch {
                Log.error("Routing", "Route calculation failed: \(error)")
            }
            return
        }
        
        guard !apiKey.isEmpty && apiKey != "YOUR_TOMTOM_API_KEY" else {
            Log.error("Routing", "Missing TomTom API key — cannot calculate route")
            return
        }
        
        let avoidAreasParam = cameras.map { $0.boundingBoxForRouting }.joined(separator: "!")
        
        do {
            var standardRoutes: [TomTomRoute] = []
            if let stdData = try await fetchTomTom(origin: origin, destination: destination, avoiding: "") {
                var mapped = stdData.routes
                for i in 0..<mapped.count {
                    let count = countCameras(on: mapped[i], cameras: cameras)
                    mapped[i].cameraCount = count
                    mapped[i].isSafeRoute = (count == 0)
                }
                standardRoutes = mapped
            }
            
            var safeRoutes: [TomTomRoute] = []
            if let safeData = try await fetchTomTom(origin: origin, destination: destination, avoiding: avoidAreasParam) {
                var mapped = safeData.routes
                for i in 0..<mapped.count {
                    mapped[i].cameraCount = 0
                    mapped[i].isSafeRoute = true
                }
                safeRoutes = mapped
            }
            
            var combined = standardRoutes
            for safe in safeRoutes {
                // Avoid exact duplicates
                if !combined.contains(where: { abs($0.summary.travelTimeInSeconds - safe.summary.travelTimeInSeconds) < 10 && abs($0.summary.lengthInMeters - safe.summary.lengthInMeters) < 100 }) {
                    combined.append(safe)
                }
            }
            
            DispatchQueue.main.async {
                self.availableRoutes = combined
                self.activeAlternativeRoutes = combined.compactMap { route in
                    route.legs.first?.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                }
                
                let defaultIndex = combined.firstIndex(where: { $0.isSafeRoute }) ?? 0
                self.selectRoute(at: defaultIndex)
                Log.info("Routing", "Got \(combined.count) routes")
            }

        } catch {
            Log.error("Routing", "Route calculation failed: \(error.localizedDescription)")
        }
    }
}
