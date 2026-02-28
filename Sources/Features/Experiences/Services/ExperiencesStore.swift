import Foundation

class ExperiencesStore: ObservableObject {
    @Published var experiences: [ExperienceSummary] = []
    
    init() {
        loadCatalog()
    }
    
    func loadCatalog() {
        guard let url = Bundle.main.url(forResource: "experiences_catalog", withExtension: "json") else {
            print("Failed to find experiences_catalog.json in bundle.")
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let catalog = try JSONDecoder().decode(ExperienceCatalog.self, from: data)
            DispatchQueue.main.async {
                self.experiences = catalog.experiences
            }
        } catch {
            print("Failed to load catalog: \(error)")
        }
    }
    
    func loadExperience(filename: String) -> ExperienceRoute? {
        // Strip .json if it was included
        let name = filename.replacingOccurrences(of: ".json", with: "")
        
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            print("Failed to find \(filename) in bundle.")
            return nil
        }
        
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ExperienceRoute.self, from: data)
        } catch {
            print("Failed to load experience \(filename): \(error)")
            return nil
        }
    }
}
