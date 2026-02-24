import Testing
import Foundation
import CoreLocation
@testable import ZenRide

// MARK: - Helpers

private func makeInstruction(
    offset: Int = 0,
    time: Int = 0,
    pointIndex: Int = 0,
    type: String? = nil,
    street: String? = nil,
    message: String? = nil
) -> TomTomInstruction {
    TomTomInstruction(
        routeOffsetInMeters: offset,
        travelTimeInSeconds: time,
        pointIndex: pointIndex,
        instructionType: type,
        street: street,
        message: message
    )
}

/// Decodes MockRoutingData JSON, manually sets availableRoutes, and calls selectRoute.
/// Uses the production (non-mock) selectRoute path so instructions/distances match
/// what real navigation sees.
private func makeServiceWithRoute(at index: Int = 0) -> RoutingService {
    let service = RoutingService()
    let data = MockRoutingData.tomTomResponseJSON.data(using: .utf8)!
    let decoded = try! JSONDecoder().decode(TomTomRouteResponse.self, from: data)
    service.availableRoutes = decoded.routes
    service.selectRoute(at: index)
    return service
}

// MARK: - Coordinate Math Tests

struct CoordinateMathTests {

    // Distance from a point to itself should be effectively zero.
    @Test func distanceToSelfIsZero() {
        let coord = CLLocationCoordinate2D(latitude: 37.7749, longitude: -122.4194)
        #expect(coord.distance(to: coord) < 0.001)
    }

    // Two points ~111m apart (0.001° latitude ≈ 111m).
    @Test func knownLatitudeDistance() {
        let a = CLLocationCoordinate2D(latitude: 37.0000, longitude: -122.0)
        let b = CLLocationCoordinate2D(latitude: 37.0010, longitude: -122.0)
        let dist = a.distance(to: b)
        // 0.001° lat ≈ 111.1m; allow ±5m tolerance
        #expect(abs(dist - 111.1) < 5.0)
    }

    // Moving due north means bearing of ~0°.
    @Test func bearingDueNorth() {
        let origin = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let north  = CLLocationCoordinate2D(latitude: 38.0, longitude: -122.0)
        let bearing = origin.bearing(to: north)
        #expect(bearing < 1.0 || bearing > 359.0) // ≈0°
    }

    // Moving due east means bearing of ~90°.
    @Test func bearingDueEast() {
        let origin = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let east   = CLLocationCoordinate2D(latitude: 37.0, longitude: -121.0)
        let bearing = origin.bearing(to: east)
        #expect(abs(bearing - 90.0) < 1.0)
    }

    // Moving due south means bearing of ~180°.
    @Test func bearingDueSouth() {
        let origin = CLLocationCoordinate2D(latitude: 38.0, longitude: -122.0)
        let south  = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let bearing = origin.bearing(to: south)
        #expect(abs(bearing - 180.0) < 1.0)
    }

    // Offsetting north by 1000m should increase latitude without changing longitude.
    @Test func offsetNorthIncreasesLatitude() {
        let origin = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let moved  = origin.coordinate(offsetBy: 1000, bearingDegrees: 0)
        #expect(moved.latitude > origin.latitude)
        #expect(abs(moved.longitude - origin.longitude) < 0.0001)
    }

    // Round-trip: offset then measure distance should recover the original distance.
    @Test func offsetRoundTripDistance() {
        let origin  = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let moved   = origin.coordinate(offsetBy: 500, bearingDegrees: 45)
        let measured = origin.distance(to: moved)
        #expect(abs(measured - 500) < 1.0) // within 1 meter
    }

    // A point at the segment midpoint should have near-zero distance to the segment.
    @Test func distanceToSegmentPointOnSegment() {
        let start = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let end   = CLLocationCoordinate2D(latitude: 37.0, longitude: -121.0)
        let mid   = CLLocationCoordinate2D(latitude: 37.0, longitude: -121.5)
        let dist  = mid.distanceToSegment(start: start, end: end)
        #expect(dist < 1.0) // effectively on the segment
    }

    // A point clearly off the side of a segment has a positive distance.
    @Test func distanceToSegmentOffSideIsPositive() {
        let start = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let end   = CLLocationCoordinate2D(latitude: 37.0, longitude: -121.0)
        // 0.01° north of midpoint ≈ 1.1km off the segment
        let off   = CLLocationCoordinate2D(latitude: 37.01, longitude: -121.5)
        let dist  = off.distanceToSegment(start: start, end: end)
        #expect(dist > 500) // clearly > 0
    }

    // Degenerate segment (start == end) falls back to point distance.
    @Test func distanceToSegmentDegenerateEqualsPointDistance() {
        let pt    = CLLocationCoordinate2D(latitude: 37.0, longitude: -122.0)
        let other = CLLocationCoordinate2D(latitude: 37.01, longitude: -122.0)
        let direct = other.distance(to: pt)
        let seg    = other.distanceToSegment(start: pt, end: pt)
        #expect(abs(seg - direct) < 0.001)
    }
}

// MARK: - TomTom Instruction Road Feature Tests

struct TomTomInstructionRoadFeatureTests {

    @Test func freewayEntryMappedCorrectly() {
        let inst = makeInstruction(type: "MOTORWAY_ENTER")
        #expect(inst.roadFeature == .freewayEntry)
    }

    @Test func freewayExitMappedCorrectly() {
        let inst = makeInstruction(type: "MOTORWAY_EXIT")
        #expect(inst.roadFeature == .freewayExit)
    }

    @Test func roundaboutPrefixMappedCorrectly() {
        for subtype in ["ROUNDABOUT_LEFT", "ROUNDABOUT_RIGHT", "ROUNDABOUT_CROSS"] {
            let inst = makeInstruction(type: subtype)
            #expect(inst.roadFeature == .roundabout)
        }
    }

    @Test func trafficLightFromMessage() {
        let inst = makeInstruction(message: "At the traffic signal, turn right")
        #expect(inst.roadFeature == .trafficLight)
    }

    @Test func trafficLightKeywordVariant() {
        let inst = makeInstruction(message: "At the traffic light, turn left")
        #expect(inst.roadFeature == .trafficLight)
    }

    @Test func stopSignFromMessage() {
        let inst = makeInstruction(message: "At the stop sign, turn left onto Howard St")
        #expect(inst.roadFeature == .stopSign)
    }

    @Test func unknownTypeReturnsNone() {
        let inst = makeInstruction(type: "TURN_RIGHT", message: "Turn right onto 3rd St")
        #expect(inst.roadFeature == .none)
    }

    @Test func nilTypeNilMessageReturnsNone() {
        let inst = makeInstruction()
        #expect(inst.roadFeature == .none)
    }
}

// MARK: - Route Selection Tests

struct RoutingServiceSelectionTests {

    // selectRoute should populate activeRoute with the leg's coordinate points.
    @Test func selectRoutePopulatesActiveRoute() {
        let service = makeServiceWithRoute(at: 0)
        #expect(!service.activeRoute.isEmpty)
        // Mock route 0 has 22 points
        #expect(service.activeRoute.count == 22)
    }

    // coordinateDistances must have the same count as activeRoute (one entry per point).
    @Test func coordinateDistancesSameCountAsRoute() {
        let service = makeServiceWithRoute(at: 0)
        #expect(service.coordinateDistances.count == service.activeRoute.count)
    }

    // First coordinate distance is always 0 (no distance traveled yet).
    @Test func coordinateDistancesStartAtZero() {
        let service = makeServiceWithRoute(at: 0)
        #expect(service.coordinateDistances.first == 0.0)
    }

    // Each entry is strictly greater than the previous (route moves forward).
    @Test func coordinateDistancesMonotonicallyIncreasing() {
        let service = makeServiceWithRoute(at: 0)
        let dists = service.coordinateDistances
        for i in 1..<dists.count {
            #expect(dists[i] > dists[i - 1])
        }
    }

    // selectRoute resets progress and instruction indices to 0.
    @Test func selectRouteResetsIndices() {
        let service = makeServiceWithRoute(at: 0)
        service.routeProgressIndex = 10
        service.currentInstructionIndex = 3
        // Reselect the same route
        service.selectRoute(at: 0)
        #expect(service.routeProgressIndex == 0)
        #expect(service.currentInstructionIndex == 0)
    }

    // distanceTraveledMeters returns 0 at the start of a route.
    @Test func distanceTraveledAtStartIsZero() {
        let service = makeServiceWithRoute(at: 0)
        #expect(service.distanceTraveledMeters == 0.0)
    }

    // distanceTraveledMeters reflects the coordinate distance at the current progress index.
    @Test func distanceTraveledAdvancesWithProgressIndex() {
        let service = makeServiceWithRoute(at: 0)
        service.routeProgressIndex = 5
        let expected = service.coordinateDistances[5]
        #expect(abs(service.distanceTraveledMeters - expected) < 0.001)
    }

    // distanceTraveledMeters clamps to last entry when index is out of range.
    @Test func distanceTraveledClampsAtEnd() {
        let service = makeServiceWithRoute(at: 0)
        service.routeProgressIndex = 9999
        let expected = service.coordinateDistances.last!
        #expect(abs(service.distanceTraveledMeters - expected) < 0.001)
    }

    // instructions are populated from the route's guidance.
    @Test func selectRoutePopulatesInstructions() {
        let service = makeServiceWithRoute(at: 0)
        // Mock route 0 has 5 instructions (START, TURN_RIGHT, MOTORWAY_ENTER, TURN_LEFT, ARRIVE)
        #expect(service.instructions.count == 5)
    }

    // Instruction content matches the mock data.
    @Test func instructionContentMatchesMockData() {
        let service = makeServiceWithRoute(at: 0)
        #expect(service.instructions[0].instructionType == "START")
        #expect(service.instructions[1].instructionType == "TURN_RIGHT")
        #expect(service.instructions[2].instructionType == "MOTORWAY_ENTER")
        #expect(service.instructions[3].instructionType == "TURN_LEFT")
        #expect(service.instructions[4].instructionType == "ARRIVE")
    }

    // Instruction offsets match the mock data (production path, not recalculated).
    @Test func instructionOffsetsMatchMockData() {
        let service = makeServiceWithRoute(at: 0)
        #expect(service.instructions[0].routeOffsetInMeters == 0)
        #expect(service.instructions[1].routeOffsetInMeters == 800)
        #expect(service.instructions[2].routeOffsetInMeters == 1400)
        #expect(service.instructions[3].routeOffsetInMeters == 1800)
        #expect(service.instructions[4].routeOffsetInMeters == 2100)
    }

    // Instruction point indices match the mock data (used for GuidanceView advancement).
    @Test func instructionPointIndicesMatchMockData() {
        let service = makeServiceWithRoute(at: 0)
        #expect(service.instructions[0].pointIndex == 0)
        #expect(service.instructions[1].pointIndex == 7)
        #expect(service.instructions[2].pointIndex == 12)
        #expect(service.instructions[3].pointIndex == 16)
        #expect(service.instructions[4].pointIndex == 21)
    }

    // roadFeature maps correctly for the mock instructions.
    @Test func instructionRoadFeaturesFromMockData() {
        let service = makeServiceWithRoute(at: 0)
        #expect(service.instructions[1].roadFeature == .trafficLight) // "At the traffic signal..."
        #expect(service.instructions[2].roadFeature == .freewayEntry) // MOTORWAY_ENTER
        #expect(service.instructions[3].roadFeature == .stopSign)     // "At the stop sign..."
    }

    // Advancing currentInstructionIndex resets haptic warning flags.
    @Test func currentInstructionIndexResetsHapticFlags() {
        let service = makeServiceWithRoute(at: 0)
        service.hasWarned500ft = true
        service.hasWarned100ft = true
        service.currentInstructionIndex = 1
        #expect(service.hasWarned500ft == false)
        #expect(service.hasWarned100ft == false)
    }

    // Out-of-bounds selectRoute should be a no-op (no crash, no state change).
    @Test func selectRouteNegativeIndexIsNoOp() {
        let service = makeServiceWithRoute(at: 0)
        let routeCount = service.activeRoute.count
        service.selectRoute(at: -1)
        #expect(service.activeRoute.count == routeCount) // unchanged
    }

    @Test func selectRouteBeyondBoundsIsNoOp() {
        let service = makeServiceWithRoute(at: 0)
        let routeCount = service.activeRoute.count
        service.selectRoute(at: 999)
        #expect(service.activeRoute.count == routeCount)
    }

    // Switching between two available routes replaces activeRoute with the new leg's points.
    @Test func switchingRoutesUpdatesActiveRoute() {
        let service = makeServiceWithRoute(at: 0)
        let route0Count = service.activeRoute.count
        service.selectRoute(at: 1)
        // Mock route 1 has 10 points — different from route 0's 22 points
        #expect(service.activeRoute.count != route0Count)
        #expect(service.activeRoute.count == 10)
    }

    // The zero-cameras route (route 1) should be tagged accordingly.
    @Test func zeroCamerasRouteIsTaggedCorrectly() {
        let service = RoutingService()
        let data = MockRoutingData.tomTomResponseJSON.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(TomTomRouteResponse.self, from: data)
        service.availableRoutes = decoded.routes
        #expect(service.availableRoutes[0].isZeroCameras == true) // cameraCount = 0 initially
        #expect(service.availableRoutes[1].tags?.contains("zero_cameras") == true)
    }
}

// MARK: - Simulation State Tests

struct SimulationStateTests {

    // simulationCompletedNaturally must start false so a fresh ride doesn't auto-end.
    @Test func simulationCompletedNaturallyStartsFalse() {
        let provider = LocationProvider()
        #expect(provider.simulationCompletedNaturally == false)
    }

    // isSimulating must start false.
    @Test func isSimulatingStartsFalse() {
        let provider = LocationProvider()
        #expect(provider.isSimulating == false)
    }

    // stopSimulation should reset simulationCompletedNaturally asynchronously.
    // We set the flag to true first, then call stopSimulation and flush the main queue.

    // stopSimulation should reset isSimulating to false.
    @Test func stopSimulationResetsIsSimulating() async {
        let provider = LocationProvider()
        // Manually set isSimulating since simulateDrive needs a real route
        provider.isSimulating = true
        provider.stopSimulation()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(provider.isSimulating == false)
    }

    // stopSimulation should reset currentSimulationIndex to 0.
    @Test func stopSimulationResetsSimulationIndex() async {
        let provider = LocationProvider()
        provider.currentSimulationIndex = 42
        provider.stopSimulation()
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(provider.currentSimulationIndex == 0)
    }

    // startNavigationSession should clear all session data so a fresh ride starts clean.
    @Test func startNavigationSessionClearsSessionData() {
        let owl = BunnyPolice()
        owl.speedReadings = [30, 45, 50]
        owl.zenScore = 75
        owl.startNavigationSession()
        #expect(owl.speedReadings.isEmpty)
    }

    // resetRideStats clears all counters.
    @Test func resetRideStatsClearsAll() {
        let owl = BunnyPolice()
        owl.camerasPassedThisRide = 5
        owl.zenScore = 60
        owl.speedReadings = [30, 45]
        owl.resetRideStats()
        #expect(owl.camerasPassedThisRide == 0)
        #expect(owl.zenScore == 100)
        #expect(owl.speedReadings.isEmpty)
        #expect(owl.currentZone == .safe)
    }
}

// MARK: - Routing Service Edge Cases
struct RoutingServiceEdgeCaseTests {

    @Test func modeDefaults() {
        let service = RoutingService()
        
        service.vehicleMode = .car
        #expect(service.avoidSpeedCameras == false)
        
        service.vehicleMode = .motorcycle
        #expect(service.avoidSpeedCameras == true)
    }

    @Test func reroutingSwitchesToAlternative() async throws {
        let service = RoutingService()
        let data = MockRoutingData.tomTomResponseJSON.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(TomTomRouteResponse.self, from: data)
        service.availableRoutes = decoded.routes
        service.selectRoute(at: 0)
        
        #expect(service.selectedRouteIndex == 0)
        
        let farLoc = CLLocation(latitude: 0, longitude: 0)
        service.checkReroute(currentLocation: farLoc)
        
        try await Task.sleep(nanoseconds: 200_000_000)
        
        #expect(service.selectedRouteIndex == 1)
    }

    @Test func reroutingBoundsAtEnd() async throws {
        let service = RoutingService()
        let data = MockRoutingData.tomTomResponseJSON.data(using: .utf8)!
        let decoded = try! JSONDecoder().decode(TomTomRouteResponse.self, from: data)
        service.availableRoutes = decoded.routes
        service.selectRoute(at: 0)
        
        service.routeProgressIndex = service.activeRoute.count - 1
        
        let endCoord = service.activeRoute.last!
        let loc = CLLocation(latitude: endCoord.latitude, longitude: endCoord.longitude)
        
        service.checkReroute(currentLocation: loc)
        
        try await Task.sleep(nanoseconds: 100_000_000)
        
        #expect(service.selectedRouteIndex == 0)
    }

    @Test func cameraCounting() {
        let service = RoutingService()
        
        let p1 = TomTomPoint(latitude: 37.0, longitude: -122.0)
        let p2 = TomTomPoint(latitude: 37.001, longitude: -122.0)
        let leg = TomTomLeg(points: [p1, p2])
        let summary = TomTomSummary(lengthInMeters: 111, travelTimeInSeconds: 10)
        let route = TomTomRoute(summary: summary, tags: nil, legs: [leg], guidance: nil)
        
        let cam1 = SpeedCamera(id: "1", street: "St", from_cross_street: nil, to_cross_street: nil, speed_limit_mph: 30, lat: 37.0, lng: -122.0)
        let cam2 = SpeedCamera(id: "2", street: "St", from_cross_street: nil, to_cross_street: nil, speed_limit_mph: 30, lat: 0.0, lng: 0.0)
        let cam3 = SpeedCamera(id: "3", street: "St", from_cross_street: nil, to_cross_street: nil, speed_limit_mph: 30, lat: 37.001, lng: -122.0005) 
        
        let cameras = [cam1, cam2, cam3]
        let count = service.countCameras(on: route, cameras: cameras)
        
        #expect(count == 2)
    }

    @Test func missingAPIKey() async throws {
        let service = RoutingService()
        service.useMockData = false
        
        await service.calculateSafeRoute(
            from: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            to: CLLocationCoordinate2D(latitude: 1, longitude: 1),
            avoiding: []
        )
        try await Task.sleep(nanoseconds: 10_000_000)
        #expect(service.isCalculatingRoute == false)
        #expect(service.availableRoutes.isEmpty)
    }
}
