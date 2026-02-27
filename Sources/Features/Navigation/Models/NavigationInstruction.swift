import Foundation

enum TurnType {
    case left
    case right
    case straight
    case uturn
    case arrive
    
    var icon: String {
        switch self {
        case .left: return "arrow.turn.up.left"
        case .right: return "arrow.turn.up.right"
        case .uturn: return "arrow.uturn.backward"
        case .arrive: return "mappin.circle.fill"
        case .straight: return "arrow.up"
        }
    }
}

struct NavigationInstruction {
    let text: String
    let distanceInMeters: Int
    let routeOffsetInMeters: Int
    let turnType: TurnType
    
    // Compatibility bridges for existing UI
    var message: String { text }
    var street: String? { nil } // Simplified for now
}
