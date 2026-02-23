import SwiftUI

struct NeonLaneGuidanceView: View {
    let instructionType: String

    @State private var appeared = false

    // MARK: - Lane Logic (deterministic — no randomElement)

    /// Fixed, sensible lane counts per instruction type.
    var totalLanes: Int {
        if instructionType.contains("TURN")  { return 3 }
        if instructionType.contains("KEEP")  { return 4 }
        return 0
    }

    /// Which lanes the driver should be in.
    /// Sharp turns → single lane; gentle keeps → two lanes.
    var activeLanes: [Int] {
        guard totalLanes > 0 else { return [] }
        switch instructionType {
        case let t where t.contains("TURN_RIGHT"): return [totalLanes - 1]
        case let t where t.contains("TURN_LEFT"):  return [0]
        case let t where t.contains("KEEP_RIGHT"): return [totalLanes - 2, totalLanes - 1]
        case let t where t.contains("KEEP_LEFT"):  return [0, 1]
        default:                                   return []
        }
    }

    /// Primary (most critical) lane — slightly larger/brighter than secondary ones.
    var primaryLane: Int? { activeLanes.first }

    var arrowIcon: String {
        if instructionType.contains("RIGHT") { return "arrow.up.right" }
        if instructionType.contains("LEFT")  { return "arrow.up.left"  }
        return "arrow.up"
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 8) {
            // "GET IN LANE" header
            HStack(spacing: 5) {
                Image(systemName: "arrow.merge")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.cyan)
                Text("GET IN LANE")
                    .font(.system(size: 9, weight: .black))
                    .foregroundColor(.cyan.opacity(0.85))
                    .kerning(1.2)
            }
            .opacity(appeared ? 1 : 0)
            .animation(.easeIn(duration: 0.25).delay(0.05), value: appeared)

            // Lane boxes
            HStack(spacing: 8) {
                ForEach(0..<totalLanes, id: \.self) { index in
                    let isActive  = activeLanes.contains(index)
                    let isPrimary = primaryLane == index

                    ZStack {
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(
                                isActive
                                    ? Color.cyan.opacity(isPrimary ? 0.22 : 0.10)
                                    : Color.white.opacity(0.04)
                            )
                            .frame(width: 34, height: 46)
                            .overlay(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .strokeBorder(
                                        isActive
                                            ? Color.cyan.opacity(isPrimary ? 1.0 : 0.45)
                                            : Color.white.opacity(0.12),
                                        lineWidth: isPrimary ? 2.5 : (isActive ? 1.5 : 1.0)
                                    )
                            )

                        if isActive {
                            Image(systemName: arrowIcon)
                                .font(.system(size: isPrimary ? 16 : 13, weight: .black))
                                .foregroundColor(.cyan.opacity(isPrimary ? 1.0 : 0.55))
                                .shadow(color: .cyan.opacity(isPrimary ? 0.9 : 0.45), radius: isPrimary ? 7 : 3)
                        } else {
                            Circle()
                                .fill(Color.white.opacity(0.18))
                                .frame(width: 5, height: 5)
                        }
                    }
                    .shadow(color: isActive ? Color.cyan.opacity(isPrimary ? 0.4 : 0.2) : .clear, radius: 8)
                    // Staggered scale-up entrance per lane
                    .scaleEffect(appeared ? 1.0 : 0.65)
                    .opacity(appeared ? 1.0 : 0.0)
                    .animation(
                        .spring(response: 0.38, dampingFraction: 0.68).delay(Double(index) * 0.06),
                        value: appeared
                    )
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 13)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
        )
        .onAppear {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation { appeared = true }
        }
    }
}
