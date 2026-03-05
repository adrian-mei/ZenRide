import XCTest
import SwiftUI
@testable import ZenMap

final class ACMapRoundButtonTests: XCTestCase {
    func testMapButtonActionFires() {
        var actionFired = false
        let button = ACMapRoundButton(icon: "map", label: "Map") {
            actionFired = true
        }
        
        // Simulate tap by calling the action directly, since ViewInspector is not available
        button.action()
        
        XCTAssertTrue(actionFired, "The map button action should fire when tapped")
    }
    
    func testCarButtonActionFires() {
        var actionFired = false
        let button = ACMapRoundButton(icon: "car", label: "Garage") {
            actionFired = true
        }
        
        button.action()
        
        XCTAssertTrue(actionFired, "The garage button action should fire when tapped")
    }
    
    func testLocationButtonActionFires() {
        var actionFired = false
        let button = ACMapRoundButton(icon: "location.fill", label: "Recenter", isActive: true) {
            actionFired = true
        }
        
        button.action()
        
        XCTAssertTrue(actionFired, "The location button action should fire when tapped")
        XCTAssertTrue(button.isActive, "The location button should reflect active state correctly")
    }
}