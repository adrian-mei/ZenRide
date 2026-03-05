import Testing
import Foundation
import CoreLocation
@testable import ZenMap

// MARK: - Helpers

private func makeRoute(name: String) -> SavedRoute {
    SavedRoute(
        destinationName: name,
        latitude: 0,
        longitude: 0,
        useCount: 0,
        lastUsedDate: Date(),
        typicalDepartureHours: [],
        averageDurationSeconds: 0
    )
}

// MARK: - Tests

struct SmartSuggestionServiceTests {

    // MARK: Home branch

    @Test func homeExactName_returnsHomePrompt() {
        let route = makeRoute(name: "home")
        #expect(SmartSuggestionService.promptText(for: route) == "Time to head home?")
    }

    @Test func homeUppercase_returnsHomePrompt() {
        let route = makeRoute(name: "HOME")
        #expect(SmartSuggestionService.promptText(for: route) == "Time to head home?")
    }

    @Test func homeSuffix_returnsHomePrompt() {
        let route = makeRoute(name: "My Home")
        #expect(SmartSuggestionService.promptText(for: route) == "Time to head home?")
    }

    // MARK: Work branch (hour-injected)

    @Test func workName_morningHour_returnsWorkPrompt() {
        let route = makeRoute(name: "Work")
        #expect(SmartSuggestionService.promptText(for: route, hour: 8) == "Head to Work?")
    }

    @Test func workName_atBoundaryHour7_returnsWorkPrompt() {
        let route = makeRoute(name: "work")
        #expect(SmartSuggestionService.promptText(for: route, hour: 7) == "Head to Work?")
    }

    @Test func workName_outsideMorning_returnsGenericPrompt() {
        let route = makeRoute(name: "Work")
        #expect(SmartSuggestionService.promptText(for: route, hour: 10) == "Heading to Work?")
    }

    // MARK: Generic branch

    @Test func genericName_returnsHeadingPrompt() {
        let route = makeRoute(name: "Coffee Shop")
        #expect(SmartSuggestionService.promptText(for: route, hour: 14) == "Heading to Coffee Shop?")
    }

    // MARK: Non-triggers

    @Test func homeworkName_doesNotTriggerHomePrompt() {
        let route = makeRoute(name: "Homework Café")
        // "homework café".hasSuffix("home") == false — safe
        #expect(SmartSuggestionService.promptText(for: route, hour: 14) == "Heading to Homework Café?")
    }
}
