import Foundation
import CoreLocation

struct CustomExperienceRoute: Codable, Identifiable {
    var id: String
    var originalExperienceId: String
    var title: String
    var stops: [ExperienceStop]
}

@MainActor
class CustomExperienceStore: ObservableObject {
    @Published var customRoutes: [CustomExperienceRoute] = []
    private let defaultsKey = "CustomExperienceRoutes"

    init() {
        load()
    }

    func saveRoute(_ route: CustomExperienceRoute) {
        customRoutes.upsert(route)
        save()
    }

    func getCustomRoute(for originalId: String) -> CustomExperienceRoute? {
        return customRoutes.first(where: { $0.originalExperienceId == originalId })
    }

    private func save() {
        UserDefaults.standard.saveJSON(customRoutes, forKey: defaultsKey)
    }

    private func load() {
        customRoutes = UserDefaults.standard.loadJSON([CustomExperienceRoute].self, forKey: defaultsKey) ?? []
    }
}
