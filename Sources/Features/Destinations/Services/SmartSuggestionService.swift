import Foundation

struct SmartSuggestionService {
    @MainActor
    static func suggestions(from store: SavedRoutesStore) -> [SavedRoute] {
        let hour = Date().hour
        return store.suggestions(for: hour)
    }

    static func promptText(for route: SavedRoute, hour: Int = Date().hour) -> String {
        let name = route.destinationName
        let nameLower = name.lowercased()

        if nameLower == "home" || nameLower.hasSuffix("home") {
            return "Time to head home?"
        } else if nameLower.contains("work") && (7...9).contains(hour) {
            return "Head to Work?"
        } else {
            return "Heading to \(name)?"
        }
    }
}
