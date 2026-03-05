import Foundation

enum RoutineCategory: String, Codable, CaseIterable {
    case home = "home"
    case work = "work"
    case gym = "gym"
    case partyMember = "party"
    case holySpot = "holy"
    case dayCare = "daycare"
    case school = "school"
    case afterSchool = "afterschool"
    case dateSpot = "datespot"
    case grocery = "grocery"
    case coffee = "coffee"

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .gym: return "dumbbell.fill"
        case .partyMember: return "person.2.fill"
        case .holySpot: return "leaf.fill"
        case .dayCare: return "teddybear.fill"
        case .school: return "figure.and.child.holdinghands"
        case .afterSchool: return "soccerball"
        case .dateSpot: return "heart.fill"
        case .grocery: return "cart.fill"
        case .coffee: return "cup.and.saucer.fill"
        }
    }

    var displayName: String {
        switch self {
        case .home: return "Home"
        case .work: return "Work"
        case .gym: return "Gym"
        case .partyMember: return "Party Member"
        case .holySpot: return "Holy Spot"
        case .dayCare: return "Day Care"
        case .school: return "School"
        case .afterSchool: return "Afterschool"
        case .dateSpot: return "Date Spot"
        case .grocery: return "Groceries"
        case .coffee: return "Coffee"
        }
    }
}
