import Foundation
import CoreLocation

// MARK: - API Models

struct TomTomRouteResponse: Codable {
    let routes: [TomTomRoute]
}

struct TomTomSummary: Codable {
    let lengthInMeters: Int
    let travelTimeInSeconds: Int
}

struct TomTomGuidance: Codable {
    let instructions: [TomTomInstruction]?
}

enum RoadFeature {
    case stopSign
    case trafficLight
    case freewayEntry
    case freewayExit
    case roundabout
    case none
}

struct TomTomInstruction: Codable {
    let routeOffsetInMeters: Int
    let travelTimeInSeconds: Int
    let pointIndex: Int
    let instructionType: String?
    let street: String?
    let message: String?

    var roadFeature: RoadFeature {
        let msg = message?.lowercased() ?? ""
        if instructionType == "MOTORWAY_ENTER" { return .freewayEntry }
        if instructionType == "MOTORWAY_EXIT" { return .freewayExit }
        if instructionType?.hasPrefix("ROUNDABOUT") == true { return .roundabout }
        if msg.contains("traffic signal") || msg.contains("traffic light") { return .trafficLight }
        if msg.contains("stop sign") { return .stopSign }
        return .none
    }
}

struct TomTomRoute: Codable, Identifiable {
    var id = UUID()
    let summary: TomTomSummary
    let tags: [String]?
    let legs: [TomTomLeg]
    let guidance: TomTomGuidance?

    var cameraCount: Int = 0
    var isSafeRoute: Bool = false
    var savedFines: Int { cameraCount * 100 }

    enum CodingKeys: String, CodingKey {
        case id, summary, tags, legs, guidance, cameraCount, isSafeRoute
    }

    var isZeroCameras: Bool {
        tags?.contains("zero_cameras") == true || isSafeRoute || cameraCount == 0
    }

    var isLessTraffic: Bool {
        tags?.contains("less_traffic") == true
    }

    var hasTolls: Bool {
        tags?.contains("has_tolls") == true
    }
}

extension TomTomRoute {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.summary = try container.decode(TomTomSummary.self, forKey: .summary)
        self.tags = try container.decodeIfPresent([String].self, forKey: .tags)
        self.legs = try container.decode([TomTomLeg].self, forKey: .legs)
        self.guidance = try container.decodeIfPresent(TomTomGuidance.self, forKey: .guidance)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.cameraCount = try container.decodeIfPresent(Int.self, forKey: .cameraCount) ?? 0
        self.isSafeRoute = try container.decodeIfPresent(Bool.self, forKey: .isSafeRoute) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(summary, forKey: .summary)
        try container.encodeIfPresent(tags, forKey: .tags)
        try container.encode(legs, forKey: .legs)
        try container.encodeIfPresent(guidance, forKey: .guidance)
        try container.encode(cameraCount, forKey: .cameraCount)
        try container.encode(isSafeRoute, forKey: .isSafeRoute)
    }
}

struct TomTomLeg: Codable {
    let points: [TomTomPoint]
}

struct TomTomPoint: Codable {
    let latitude: Double
    let longitude: Double
}
