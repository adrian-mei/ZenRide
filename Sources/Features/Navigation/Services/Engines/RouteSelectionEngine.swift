import Foundation
import CoreLocation

enum RouteSelectionEngine {
    static func mapTurnType(from tomtomType: String?) -> TurnType {
        guard let type = tomtomType else { return .straight }
        if type == "TURN_LEFT" || type == "KEEP_LEFT" { return .left }
        if type == "TURN_RIGHT" || type == "KEEP_RIGHT" { return .right }
        if type == "ARRIVE" { return .arrive }
        if type.contains("UTURN") { return .uturn }
        return .straight
    }

    struct SelectionResult {
        let activeRoute: [CLLocationCoordinate2D]
        let coordinateDistances: [Double]
        let routeDistanceMeters: Int
        let routeTimeSeconds: Int
        let instructions: [NavigationInstruction]
    }

    static func processSelection(route: TomTomRoute, useMockData: Bool) -> SelectionResult {
        var activeRoute: [CLLocationCoordinate2D] = []
        var totalCalculatedDistance = 0.0
        var coordinateDistances: [Double] = [0.0]

        if let firstLeg = route.legs.first {
            activeRoute = firstLeg.points.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

            for i in 1..<activeRoute.count {
                let dist = activeRoute[i-1].distance(to: activeRoute[i])
                totalCalculatedDistance += dist
                coordinateDistances.append(totalCalculatedDistance)
            }
        }

        let routeDistanceMeters: Int
        let routeTimeSeconds: Int
        let instructions: [NavigationInstruction]

        if useMockData {
            routeDistanceMeters = Int(totalCalculatedDistance)
            routeTimeSeconds = Int(totalCalculatedDistance / 15.0)

            if let oldInstructions = route.guidance?.instructions {
                instructions = oldInstructions.map { inst in
                    let trueOffset = inst.pointIndex < coordinateDistances.count ? Int(coordinateDistances[inst.pointIndex]) : Int(totalCalculatedDistance)
                    return NavigationInstruction(
                        text: inst.message ?? "Continue",
                        distanceInMeters: 50,
                        routeOffsetInMeters: trueOffset,
                        pointIndex: inst.pointIndex,
                        turnType: mapTurnType(from: inst.instructionType)
                    )
                }
            } else {
                instructions = []
            }
        } else {
            routeDistanceMeters = route.summary.lengthInMeters
            routeTimeSeconds = route.summary.travelTimeInSeconds
            if let tomtom = route.guidance?.instructions {
                instructions = tomtom.map { inst in
                    NavigationInstruction(
                        text: inst.message ?? "Continue",
                        distanceInMeters: 50,
                        routeOffsetInMeters: inst.routeOffsetInMeters,
                        pointIndex: inst.pointIndex,
                        turnType: mapTurnType(from: inst.instructionType)
                    )
                }
            } else {
                instructions = []
            }
        }

        return SelectionResult(
            activeRoute: activeRoute,
            coordinateDistances: coordinateDistances,
            routeDistanceMeters: routeDistanceMeters,
            routeTimeSeconds: routeTimeSeconds,
            instructions: instructions
        )
    }
}
