import SwiftUI

struct GuidanceView: View {
    @EnvironmentObject var routingService: RoutingService
    @EnvironmentObject var owlPolice: OwlPolice
    
    var body: some View {
        VStack {
            if !routingService.instructions.isEmpty, routingService.currentInstructionIndex < routingService.instructions.count {
                let instruction = routingService.instructions[routingService.currentInstructionIndex]
                
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
                .padding(20)
                .background(Color(red: 0.1, green: 0.55, blue: 0.25), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.3), radius: 12, x: 0, y: 8)
                .padding(.horizontal, 16)
            }
        }
        // Advance instructions based on our simulation point index.
        // We look for the first instruction whose pointIndex is strictly greater than our current simulation point.
        .onChange(of: owlPolice.currentSimulationIndex) { newIndex in
            if owlPolice.isSimulating {
                if let nextInstructionIndex = routingService.instructions.firstIndex(where: { $0.pointIndex > newIndex }) {
                    // Show the upcoming instruction
                    if routingService.currentInstructionIndex != nextInstructionIndex {
                        routingService.currentInstructionIndex = nextInstructionIndex
                    }
                } else if !routingService.instructions.isEmpty {
                    // If we passed all triggers, show the last one (ARRIVE)
                    let lastIndex = routingService.instructions.count - 1
                    if routingService.currentInstructionIndex != lastIndex {
                        routingService.currentInstructionIndex = lastIndex
                    }
                }
            }
        }
        .onChange(of: routingService.currentInstructionIndex) { index in
            if index >= 0 && index < routingService.instructions.count {
                if let message = routingService.instructions[index].message {
                    owlPolice.speak(message)
                }
            }
        }
        .onChange(of: owlPolice.isSimulating) { isSimulating in
             if isSimulating {
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
