import SwiftUI

struct GuidanceView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var bunnyPolice: BunnyPolice
    @EnvironmentObject var locationProvider: LocationProvider
    @State private var currentInstructionIndex: Int = 0
    @State private var isApproachingTurn = false   // < 300ft to next turn
    private let haptic500 = UINotificationFeedbackGenerator()
    private let haptic100 = UIImpactFeedbackGenerator(style: .heavy)

    var body: some View {
        VStack {
            if !routingService.instructions.isEmpty, currentInstructionIndex < routingService.instructions.count {
                let instruction = routingService.instructions[currentInstructionIndex]
                
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Image(systemName: iconForInstruction(instruction.instructionType))
                            .font(.system(size: 48, weight: .heavy))
                            .foregroundColor(.cyan)
                            .scaleEffect(isApproachingTurn ? 1.1 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isApproachingTurn)
                            .frame(width: 80)
                        
                        Text(formatDistance(instruction: instruction))
                            .font(.system(size: 24, weight: .black, design: .monospaced)) // Thicker, digital distance
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instruction.message ?? "Continue")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(1)

                        if let street = instruction.street, !street.isEmpty {
                            Text(street)
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
                        } else {
                            Text("Main Route")
                                .font(.system(size: 34, weight: .black))
                                .foregroundColor(.white)
                        }

                        // Road feature badge
                        let feature = instruction.roadFeature
                        if feature != .none {
                            roadFeatureBadge(feature)
                        }
                    }

                    Spacer()

                    // Vehicle mode badge (top-right of card)
                    VStack {
                        Image(systemName: routingService.vehicleMode.icon)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.5))
                            .padding(8)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, (instruction.instructionType?.contains("TURN") == true || instruction.instructionType?.contains("KEEP") == true) ? 4 : 20)
                
                // --- NEW: Next Turn Preview ---
                let traveled = locationProvider.isSimulating ? locationProvider.distanceTraveledInSimulationMeters : routingService.distanceTraveledMeters
                let currentDist = Double(instruction.routeOffsetInMeters) - traveled
                if currentDist > 1600 && currentInstructionIndex + 1 < routingService.instructions.count {
                    let nextInst = routingService.instructions[currentInstructionIndex + 1]
                    if nextInst.instructionType != "ARRIVE" {
                        HStack(spacing: 8) {
                            Text("THEN:")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white.opacity(0.6))
                            Image(systemName: iconForInstruction(nextInst.instructionType))
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                            Text(nextInst.street ?? nextInst.message ?? "")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.white.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 16)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                // -----------------------------
                
                // --- NEON LANE GUIDANCE ---
                if let type = instruction.instructionType, type.contains("TURN") || type.contains("KEEP") {
                    let traveled2 = locationProvider.isSimulating ? locationProvider.distanceTraveledInSimulationMeters : routingService.distanceTraveledMeters
                    let distanceToTurn = Double(instruction.routeOffsetInMeters) - traveled2
                    if distanceToTurn < 1000 && distanceToTurn > 100 {
                        NeonLaneGuidanceView(instructionType: type)
                            .padding(.bottom, 16)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                // --------------------------
                
                } // End of inner VStack
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .environment(\.colorScheme, .dark)
                .overlay(
                    Group {
                        if instruction.instructionType == "ARRIVE" {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.green.opacity(0.15))
                        }
                    }
                )
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 6)
                .padding(.horizontal, 12)
                .id(currentInstructionIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
        .onAppear {
            haptic500.prepare()
            haptic100.prepare()
        }
        // Advance instructions based on our simulation point index.
        // We look for the first instruction whose pointIndex is strictly greater than our current simulation point.
        .onChange(of: locationProvider.currentSimulationIndex) { newIndex in
            if locationProvider.isSimulating {
                if let nextInstructionIndex = routingService.instructions.firstIndex(where: { $0.pointIndex > newIndex }) {
                    if routingService.currentInstructionIndex != nextInstructionIndex {
                        routingService.currentInstructionIndex = nextInstructionIndex
                    }
                } else if !routingService.instructions.isEmpty {
                    let lastIndex = routingService.instructions.count - 1
                    if routingService.currentInstructionIndex != lastIndex {
                        routingService.currentInstructionIndex = lastIndex
                    }
                }
            }
        }
        .onChange(of: routingService.currentInstructionIndex) { index in
            if index >= 0 && index < routingService.instructions.count {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    currentInstructionIndex = index
                    isApproachingTurn = false   // reset surge on instruction change
                }
                if let message = routingService.instructions[index].message {
                    bunnyPolice.speak(message)
                }
            }
        }
        .onChange(of: locationProvider.isSimulating) { isSimulating in
            if isSimulating {
                currentInstructionIndex = 0
                routingService.currentInstructionIndex = 0
            }
        }
        // Simulation: 60fps distance updates drive haptics + approach surge
        .onChange(of: locationProvider.distanceTraveledInSimulationMeters) { dist in
            guard locationProvider.isSimulating else { return }
            updateApproachState(distanceTraveled: dist)
        }
        // Real GPS: instruction advancement + approach driven by route progress segment
        .onChange(of: routingService.routeProgressIndex) { progressIndex in
            guard !locationProvider.isSimulating else { return }
            // Advance to the next instruction whose point is still ahead of us
            if let nextIdx = routingService.instructions.firstIndex(where: { $0.pointIndex > progressIndex }) {
                if routingService.currentInstructionIndex != nextIdx {
                    routingService.currentInstructionIndex = nextIdx
                }
            } else if !routingService.instructions.isEmpty {
                let lastIdx = routingService.instructions.count - 1
                if routingService.currentInstructionIndex != lastIdx {
                    routingService.currentInstructionIndex = lastIdx
                }
            }
            updateApproachState(distanceTraveled: routingService.distanceTraveledMeters)
        }
    }

    private func updateApproachState(distanceTraveled: Double) {
        guard !routingService.instructions.isEmpty,
              currentInstructionIndex < routingService.instructions.count else { return }
        let instruction = routingService.instructions[currentInstructionIndex]
        let nextInstructionDistanceMeters = Double(instruction.routeOffsetInMeters) - distanceTraveled
        let distanceFeet = max(0, nextInstructionDistanceMeters * 3.28084)

        if distanceFeet < 510 && distanceFeet > 490 && !routingService.hasWarned500ft {
            routingService.hasWarned500ft = true
            haptic500.notificationOccurred(.warning)
        }
        if distanceFeet < 110 && distanceFeet > 90 && !routingService.hasWarned100ft {
            routingService.hasWarned100ft = true
            haptic100.impactOccurred()
        }
        let approaching = distanceFeet > 0 && distanceFeet < 300
        if approaching != isApproachingTurn {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                isApproachingTurn = approaching
            }
        }
    }
    
    @ViewBuilder
    private func roadFeatureBadge(_ feature: RoadFeature) -> some View {
        let (icon, color, label): (String, Color, String) = {
            switch feature {
            case .stopSign:    return ("octagon.fill", .red, "STOP SIGN")
            case .trafficLight: return ("light.beacon.max.fill", Color(red: 1, green: 0.75, blue: 0), "SIGNAL")
            case .freewayEntry: return ("arrow.up.right.square.fill", .cyan, "ON-RAMP")
            case .freewayExit:  return ("arrow.down.right.square.fill", Color.orange, "EXIT")
            case .roundabout:   return ("arrow.clockwise.circle.fill", .white, "ROUNDABOUT")
            case .none:         return ("", .clear, "")
            }
        }()
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
            Text(label)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
        .foregroundColor(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.15))
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
    }

    private func iconForInstruction(_ type: String?) -> String {
        switch type {
        case "TURN_RIGHT":       return "arrow.turn.up.right"
        case "TURN_LEFT":        return "arrow.turn.up.left"
        case "KEEP_RIGHT":       return "arrow.up.right"
        case "KEEP_LEFT":        return "arrow.up.left"
        case "START":            return "location.fill"
        case "ARRIVE":           return "mappin.circle.fill"
        case "MOTORWAY_ENTER":   return "arrow.up.right.square.fill"
        case "MOTORWAY_EXIT":    return "arrow.down.right.square.fill"
        case "ROUNDABOUT_LEFT":  return "arrow.counterclockwise.circle.fill"
        case "ROUNDABOUT_RIGHT": return "arrow.clockwise.circle.fill"
        case "STRAIGHT":         return "arrow.up"
        default:                 return "arrow.up"
        }
    }
}

extension GuidanceView {
    private func formatDistance(instruction: TomTomInstruction) -> String {
        let traveled = locationProvider.isSimulating
            ? locationProvider.distanceTraveledInSimulationMeters
            : routingService.distanceTraveledMeters
        let nextInstructionDistanceMeters = Double(instruction.routeOffsetInMeters) - traveled
        let distanceFeet = max(0, nextInstructionDistanceMeters * 3.28084)
        let distanceMiles = distanceFeet / 5280
        
        if distanceFeet < 1000 {
            let roundedFeet = Int(round(distanceFeet / 50.0) * 50)
            return "\(max(50, roundedFeet)) ft" // Never show 0 while moving
        } else {
            return String(format: "%.1f mi", distanceMiles)
        }
    }
}
