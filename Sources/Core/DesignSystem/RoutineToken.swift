import SwiftUI

// MARK: - RoutineToken

public struct RoutineToken: View {
    let category: RoutineCategory
    let index: Int
    let route: SavedRoute?
    var isPredicted: Bool = false
    var action: () -> Void
    
    init(category: RoutineCategory, index: Int, route: SavedRoute?, isPredicted: Bool = false, action: @escaping () -> Void) {
        self.category = category
        self.index = index
        self.route = route
        self.isPredicted = isPredicted
        self.action = action
    }

    public var body: some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        }) {
            VStack(spacing: 8) {
                ZStack {
                    // Depth slab
                    Circle()
                        .fill(Theme.Colors.acBorder.opacity(0.8))
                        .offset(y: 4)

                    // Main face
                    Circle()
                        .fill(faceColor)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 2)
                        )

                    // Content
                    if let route = route {
                        if category == .partyMember, let _ = route.contactIdentifier {
                            // Contact Photo placeholder (Ideally would fetch from CNContact)
                            Image(systemName: "person.crop.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .foregroundColor(.white.opacity(0.8))
                                .padding(8)
                        } else {
                            Image(systemName: customIcon ?? category.icon)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: "plus")
                            .font(.system(size: 20, weight: .black))
                            .foregroundColor(Theme.Colors.acBorder.opacity(0.5))
                    }
                }
                .frame(width: 64, height: 64)
                .acWobble(isPressed: false)
                .overlay(
                    Group {
                        if isPredicted {
                            Circle()
                                .stroke(Theme.Colors.acGold, lineWidth: 3)
                                .scaleEffect(1.2)
                                .opacity(0.6)
                        }
                    }
                )

                Text(label)
                    .font(Theme.Typography.caption)
                    .foregroundColor(Theme.Colors.acTextDark)
                    .lineLimit(1)
                    .frame(width: 70)
            }
        }
        .buttonStyle(.plain)
    }

    private var faceColor: Color {
        if route == nil { return Theme.Colors.acField }
        switch category {
        case .home: return Theme.Colors.acLeaf
        case .work: return Theme.Colors.acWood
        case .gym: return Theme.Colors.acSky
        case .partyMember: return Theme.Colors.acCoral
        case .holySpot: return Theme.Colors.acGold
        case .dayCare: return Theme.Colors.acMint
        case .school: return Theme.Colors.acSky
        case .afterSchool: return Theme.Colors.acCoral
        case .dateSpot: return Theme.Colors.acCoral
        case .grocery: return Theme.Colors.acLeaf
        case .coffee: return Theme.Colors.acWood
        }
    }

    private var label: String {
        if let route = route {
            return route.destinationName
        }
        return "\(category.displayName) \(index + 1)"
    }

    private var customIcon: String? {
        route?.customIcon
    }
}
