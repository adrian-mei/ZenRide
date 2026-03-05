import Foundation
import CoreLocation

// MARK: - API Client

actor TomTomRoutingClient {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }
    
    func fetchRoute(
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        avoidAreas: String,
        avoidFeatures: [String],
        travelMode: String
    ) async throws -> TomTomRouteResponse? {
        // Construct URL
        let urlString = "https://api.tomtom.com/routing/1/calculateRoute/\(origin.latitude),\(origin.longitude):\(destination.latitude),\(destination.longitude)/json"
        
        guard var components = URLComponents(string: urlString) else {
            throw RoutingError.invalidURL
        }
        
        var queryItems: [URLQueryItem] = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "routeType", value: "fastest"),
            URLQueryItem(name: "computeBestOrder", value: "false"),
            URLQueryItem(name: "maxAlternatives", value: "2"),
            URLQueryItem(name: "traffic", value: "true"),
            URLQueryItem(name: "instructionsType", value: "text"),
            URLQueryItem(name: "language", value: "en-US"),
            URLQueryItem(name: "travelMode", value: travelMode)
        ]
        
        if !avoidAreas.isEmpty {
            queryItems.append(URLQueryItem(name: "avoidAreas", value: avoidAreas))
        }
        
        if !avoidFeatures.isEmpty {
            queryItems.append(URLQueryItem(name: "avoid", value: avoidFeatures.joined(separator: ",")))
        }
        
        components.queryItems = queryItems
        
        guard let url = components.url else {
            throw RoutingError.invalidURL
        }
        
        // Fetch Data
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            if let httpResponse = response as? HTTPURLResponse {
                Log.error("Routing", "TomTom HTTP \(httpResponse.statusCode)")
            }
            return nil
        }
        
        return try JSONDecoder().decode(TomTomRouteResponse.self, from: data)
    }
}
