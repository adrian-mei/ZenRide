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
        if let index = customRoutes.firstIndex(where: { $0.id == route.id }) {
            customRoutes[index] = route
        } else {
            customRoutes.append(route)
        }
        save()
    }
    
    func getCustomRoute(for originalId: String) -> CustomExperienceRoute? {
        return customRoutes.first(where: { $0.originalExperienceId == originalId })
    }
    
    private func save() {
        if let data = try? JSONEncoder().encode(customRoutes) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: defaultsKey),
           let decoded = try? JSONDecoder().decode([CustomExperienceRoute].self, from: data) {
            customRoutes = decoded
        }
    }
}
