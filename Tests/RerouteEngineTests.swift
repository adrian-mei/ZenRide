import Testing
import Foundation
import CoreLocation
@testable import ZenMap

struct RerouteEngineTests {
    
    @Test("Throttles reroute checks")
    func testThrottling() {
        let now = Date()
        let lastCheck = now.addingTimeInterval(-0.5) // Less than 1 second ago
        
        let result = RerouteEngine.evaluate(
            currentLocation: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            activeRoute: [],
            routeProgressIndex: 0,
            isCalculatingRoute: false,
            showReroutePrompt: false,
            lastRerouteCheckTime: lastCheck,
            now: now
        )
        
        switch result.action {
        case .none:
            #expect(true)
        default:
            Issue.record("Expected .none action due to throttling")
        }
        
        #expect(result.newCheckTime == lastCheck)
    }
}
