import SwiftUI

struct GuidanceView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var owlPolice: OwlPolice
    @State private var currentInstructionIndex: Int = 0

    var body: some View {
        VStack {
            if !routingService.instructions.isEmpty, currentInstructionIndex < routingService.instructions.count {
                let instruction = routingService.instructions[currentInstructionIndex]
                
                VStack(spacing: 0) {
                    HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Image(systemName: iconForInstruction(instruction.instructionType))
                            .font(.system(size: 48, weight: .heavy)) // Larger arrow for driving
                            .foregroundColor(.white)
                            .frame(width: 80)
                        
                        Text(formatDistance(instruction: instruction))
                            .font(.system(size: 24, weight: .black)) // Thicker, larger distance
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(instruction.message ?? "Continue")
                            .font(.system(size: 22, weight: .bold)) // Larger instruction message
                            .foregroundColor(.white.opacity(0.85))
                            .lineLimit(1)
                        
                        if let street = instruction.street, !street.isEmpty {
                            Text(street)
                                .font(.system(size: 34, weight: .black)) // Massive street name
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
                
                } // End of inner VStack
                .background(
                    ZStack {
                        if instruction.instructionType == "ARRIVE" {
                            Color(red: 0.8, green: 0.6, blue: 0.1).opacity(0.85)
                        } else {
                            Color(red: 0.05, green: 0.45, blue: 0.2).opacity(0.85)
                        }
                        
                        // Subtle inner gloss
                        LinearGradient(
                            colors: [.white.opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 10)
                .padding(.horizontal, 12)
                .id(currentInstructionIndex)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
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
