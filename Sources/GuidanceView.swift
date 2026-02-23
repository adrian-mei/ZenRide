import SwiftUI

struct GuidanceView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var owlPolice: OwlPolice
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
                            .shadow(color: .cyan.opacity(isApproachingTurn ? 0.95 : 0.6),
                                    radius: isApproachingTurn ? 18 : 5)
                            .scaleEffect(isApproachingTurn ? 1.14 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.65), value: isApproachingTurn)
                            .frame(width: 80)
                        
                        Text(formatDistance(instruction: instruction))
                            .font(.system(size: 24, weight: .black, design: .monospaced)) // Thicker, digital distance
                            .foregroundColor(.white)
                            .contentTransition(.numericText())
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instruction.message ?? "Continue")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.cyan.opacity(0.85))
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
                let currentDist = Double(instruction.routeOffsetInMeters) - owlPolice.distanceTraveledInSimulationMeters
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
                    let distanceToTurn = Double(instruction.routeOffsetInMeters) - owlPolice.distanceTraveledInSimulationMeters
                    if distanceToTurn < 1000 && distanceToTurn > 100 {
                        NeonLaneGuidanceView(instructionType: type)
                            .padding(.bottom, 16)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                    }
                }
                // --------------------------
                
                } // End of inner VStack
                .background(
                    ZStack {
                        if instruction.instructionType == "ARRIVE" {
                            Color(red: 0.8, green: 0.5, blue: 0.0).opacity(0.95)
                        } else {
                            // "Night Rider" Deep Indigo-Cyan gradient
                            LinearGradient(
                                colors: [Color(red: 0.0, green: 0.2, blue: 0.4).opacity(0.95), Color(red: 0.05, green: 0.05, blue: 0.15).opacity(0.98)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                        
                        // Subtle inner gloss for the HUD look
                        LinearGradient(
                            colors: [.white.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous)) // Reverted VisorShape for better content fitting on all devices
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.cyan.opacity(isApproachingTurn ? 0.9 : 0.5),
                              lineWidth: isApproachingTurn ? 3.0 : 2.0)
                )
                .shadow(color: .cyan.opacity(isApproachingTurn ? 0.5 : 0.2),
                        radius: isApproachingTurn ? 26 : 15, x: 0, y: 10)
                .scaleEffect(isApproachingTurn ? 1.018 : 1.0)
                .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isApproachingTurn)
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
        .onChange(of: owlPolice.currentSimulationIndex) { newIndex in
            if owlPolice.isSimulating {
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
                    owlPolice.speak(message)
                }
            }
        }
        .onChange(of: owlPolice.isSimulating) { isSimulating in
            if isSimulating {
                currentInstructionIndex = 0
                routingService.currentInstructionIndex = 0
            }
        }
        .onChange(of: owlPolice.distanceTraveledInSimulationMeters) { dist in
            if !routingService.instructions.isEmpty, currentInstructionIndex < routingService.instructions.count {
                let instruction = routingService.instructions[currentInstructionIndex]
                let nextInstructionDistanceMeters = Double(instruction.routeOffsetInMeters) - dist
                let distanceFeet = max(0, nextInstructionDistanceMeters * 3.28084)
                
                // Haptic at 500ft
                if distanceFeet < 510 && distanceFeet > 490 && !routingService.hasWarned500ft {
                    routingService.hasWarned500ft = true
                    haptic500.notificationOccurred(.warning)
                }

                // Haptic at 100ft
                if distanceFeet < 110 && distanceFeet > 90 && !routingService.hasWarned100ft {
                    routingService.hasWarned100ft = true
                    haptic100.impactOccurred()
                }

                // Approach surge: card scales + glows when < 300ft to turn
                let approaching = distanceFeet > 0 && distanceFeet < 300
                if approaching != isApproachingTurn {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
                        isApproachingTurn = approaching
                    }
                }
            }
        }
    }
    
    private func iconForInstruction(_ type: String?) -> String {
        switch type {
        case "TURN_RIGHT": return "arrow.turn.up.right"
        case "TURN_LEFT": return "arrow.turn.up.left"
        case "KEEP_RIGHT": return "arrow.up.right"
        case "KEEP_LEFT": return "arrow.up.left"
        case "START": return "location.fill" // Replaced car with neutral location arrow
        case "ARRIVE": return "mappin.circle.fill"
        default: return "arrow.up"
        }
    }
}

extension GuidanceView {
    private func formatDistance(instruction: TomTomInstruction) -> String {
        let nextInstructionDistanceMeters = Double(instruction.routeOffsetInMeters) - owlPolice.distanceTraveledInSimulationMeters
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
