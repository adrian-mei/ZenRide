import XCTest
@testable import ZenMap

final class DestinationSearchViewModelTests: XCTestCase {
    
    func testScore_ExactMatch() {
        let name = "starbucks"
        let query = "starbucks"
        let score = DestinationSearcher.score(name: name, query: query)
        XCTAssertEqual(score, 4, "Exact match should have score 4")
    }
    
    func testScore_PrefixMatch() {
        let name = "starbucks coffee"
        let query = "starbucks"
        let score = DestinationSearcher.score(name: name, query: query)
        XCTAssertEqual(score, 3, "Prefix match should have score 3")
    }
    
    func testScore_ContainsMatch() {
        let name = "the starbucks"
        let query = "starbucks"
        let score = DestinationSearcher.score(name: name, query: query)
        XCTAssertEqual(score, 2, "Contains match should have score 2")
    }
    
    func testScore_NoMatch() {
        let name = "dunkin"
        let query = "starbucks"
        let score = DestinationSearcher.score(name: name, query: query)
        XCTAssertEqual(score, 1, "No match logic falls through to 1 (default return)")
    }
}
