import re

with open("Sources/RoutingService.swift", "r") as f:
    content = f.read()

helper_code = """
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
            return nil
        }
        
        return try JSONDecoder().decode(TomTomRouteResponse.self, from: data)
    }
"""

calculate_code = """    func calculateSafeRoute(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, avoiding cameras: [SpeedCamera]) async {
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
                    
                    print("Successfully loaded mock routes: \(result.routes.count)")
                }
            } catch {
                print("Failed to decode mock route: \(error)")
            }
            return
        }
        
        guard !apiKey.isEmpty && apiKey != "YOUR_TOMTOM_API_KEY" else {
            print("Missing TomTom API Key. Cannot calculate route.")
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
                print("Successfully calculated safe routes. Total alternatives: \(combined.count)")
            }
            
        } catch {
            print("Routing Service Error: \(error.localizedDescription)")
        }
    }"""

pattern = re.compile(r"    func calculateSafeRoute\(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, avoiding cameras: \[SpeedCamera\]\) async \{.*", re.DOTALL)
new_content = re.sub(pattern, helper_code + "\n" + calculate_code + "\n}\n", content)

with open("Sources/RoutingService.swift", "w") as f:
    f.write(new_content)
