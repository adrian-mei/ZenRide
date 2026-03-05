import Foundation

@MainActor
class VehicleGarageViewModel: ObservableObject {
    @Published var hoveredId: String = "classic_sedan"

    var hoveredTemplate: VehicleTemplate {
        VehicleTemplate.all.first { $0.id == hoveredId } ?? VehicleTemplate.all[0]
    }

    var freeTemplates: [VehicleTemplate] {
        VehicleTemplate.all.filter { $0.unlockLevel == 1 }
    }
    
    var lockedTemplates: [VehicleTemplate] {
        VehicleTemplate.all.filter { $0.unlockLevel > 1 && $0.unlockLevel < 40 }
    }
    
    var legendaryTemplates: [VehicleTemplate] {
        VehicleTemplate.all.filter { $0.unlockLevel >= 40 }
    }
}
