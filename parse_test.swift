import Foundation

let json = """
{
  "formatVersion": "0.0.12",
  "routes": [
    {
      "summary": {
        "lengthInMeters": 2100,
        "travelTimeInSeconds": 450
      },
      "legs": [
        {
          "summary": {
            "lengthInMeters": 2100,
            "travelTimeInSeconds": 450
          },
          "points": [
            {"latitude": 37.77490, "longitude": -122.41940}
          ]
        }
      ],
      "guidance": {
        "instructions": [
          {
            "routeOffsetInMeters": 0,
            "travelTimeInSeconds": 0,
            "point": {"latitude": 37.77490, "longitude": -122.41940},
            "pointIndex": 0,
            "instructionType": "TURN_RIGHT",
            "street": "Market St",
            "message": "Turn right onto Market St"
          }
        ]
      }
    }
  ]
}
"""

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

struct TomTomRoute: Decodable {
    let summary: TomTomSummary
    let legs: [TomTomLeg]
    let guidance: TomTomGuidance?
}

struct TomTomLeg: Decodable {
    let points: [TomTomPoint]
}

struct TomTomPoint: Decodable {
    let latitude: Double
    let longitude: Double
}

do {
    let data = json.data(using: .utf8)!
    let result = try JSONDecoder().decode(TomTomRouteResponse.self, from: data)
    print("Success: \(result.routes.first?.guidance?.instructions?.count ?? 0) instructions")
} catch {
    print("Error: \(error)")
}
